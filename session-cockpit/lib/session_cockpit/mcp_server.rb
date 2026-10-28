# frozen_string_literal: true

require "mcp"

module SessionCockpit
  # The MCP server is the only writer of a session's event log: Claude's tool
  # calls go straight in, and what the user submits from Emacs is taken over
  # from the session's inbox.
  module MCPServer
    INSTRUCTIONS = "These tools put questions into the user's session cockpit, an Emacs buffer where they " \
                   "answer at their own pace. They work while the session's cockpit is on, which the " \
                   "start-cockpit skill turns on."

    # MONITOR_COMMAND starts the monitor, for Claude to run by hand when the
    # plugin's own monitor isn't running.
    def self.run(repository:, claude_pid:, initial_session_id:, monitor_command:)
      Thread.new do
        loop do
          repository.current_session_state(claude_pid: claude_pid, fallback: initial_session_id).integrate_inbox
          sleep 0.1
        end
      end
      context = { repository: repository, claude_pid: claude_pid, initial_session_id: initial_session_id,
                  monitor_command: monitor_command }
      tools = [GetQuestions, Ask, UpdateQuestions, WithdrawQuestions]
      server = MCP::Server.new(name: "session-cockpit", instructions: INSTRUCTIONS, tools: tools,
                               server_context: context)
      MCP::Server::Transports::StdioTransport.new(server).open
    end

    # A tool that turns Claude's call into events in the current session's
    # log. Defined above the tools, since Ruby needs a superclass first.
    class AgendaTool < MCP::Tool
      OPTION_SCHEMA = {
        type: "object",
        properties: {
          label: { type: "string", description: "What the user picks, in a few words" },
          description: { type: "string", description: "What picking it means" },
          preview: { type: "string", description: "Optional text shown below the option, such as code" }
        },
        required: %w[label description]
      }.freeze

      ANCHOR_SCHEMA = {
        type: "object",
        properties: {
          file: { type: "string", description: "Path of the file, absolute or relative to the project" },
          start: { type: "integer", minimum: 1, description: "First line" },
          end: { type: "integer", minimum: 1, description: "Last line; the first line if left out" }
        },
        required: %w[file start]
      }.freeze

      QUESTION_PROPERTIES = {
        question: { type: "string", description: "The complete question" },
        options: { type: "array", maxItems: 4, items: OPTION_SCHEMA,
                   description: "2 to 4 options when the answer is a choice, the one you recommend first " \
                                "with \"(Recommended)\" after its label; none for an answer in free text" },
        multiSelect: { type: "boolean", description: "Whether the user may pick several options" },
        anchors: { type: "array", items: ANCHOR_SCHEMA,
                   description: "Lines in files the question is about. The user sees them below the " \
                                "question and marked in the file, so name lines rather than quoting them." }
      }.freeze

      ID_SCHEMA = { type: "string", description: "ID of the question, such as q1" }.freeze

      # Answers Claude with the text the block returns, or with the reason a
      # Refusal gives.
      def self.respond
        MCP::Tool::Response.new([{ type: "text", text: yield }])
      rescue Refusal => e
        MCP::Tool::Response.new([{ type: "text", text: e.message }], error: true)
      end

      # Logs the events the block builds from the session's agenda as it is
      # now, all or none, and returns them.
      def self.log_events(server_context, &build_events)
        current_session_state(server_context).append_all(&build_events)
      end

      # The state of the session Claude Code is in now. Refuses unless its
      # cockpit is on and the monitor runs, since otherwise the user's
      # answers never reach Claude.
      def self.current_session_state(server_context)
        repository = server_context.fetch(:repository)
        claude_pid = server_context.fetch(:claude_pid)
        state = repository.current_session_state(claude_pid: claude_pid,
                                                 fallback: server_context.fetch(:initial_session_id))
        unless state.cockpit_on?
          raise Refusal, "The cockpit is not on for this session. Run the start-cockpit skill to turn it on."
        end
        unless repository.monitor_running?(claude_pid: claude_pid)
          raise Refusal, <<~TEXT.chomp
            The monitor that brings the user's answers to you is not running. Run the start-cockpit skill to start it. If it ran already since Claude Code started, start this command with your Monitor tool instead, at the longest timeout, and start it again whenever it expires:
            CLAUDE_CODE_SESSION_ID=#{state.id} #{server_context.fetch(:monitor_command)}
          TEXT
        end
        state
      end

      # VALUE with string keys all the way down, as it is logged.
      def self.plain(value) = JSON.parse(JSON.generate(value))

      # Refuses what the input schema cannot: a single option, which is no
      # choice, and options with the same label.
      def self.check_question(question)
        labels = question.fetch("options", []).map { it["label"] }
        if labels.length == 1
          raise Refusal, "A question has 2 to 4 options, or none: #{question["question"] || question["id"]}"
        end
        raise Refusal, "Option labels repeat: #{labels.join(", ")}" if labels.uniq.length < labels.length
      end

      # QUESTION with its anchors as they are logged: each file's absolute
      # path, its line range complete and the text of those lines, so Emacs
      # can find them again once the file changes.
      def self.with_anchors_read(question, server_context)
        return question unless question.key?("anchors")

        project = current_session_state(server_context).project
        question.merge("anchors" => question["anchors"].map { read_anchor(it, project) })
      end

      # ANCHOR with its file read: a relative path is relative to PROJECT.
      def self.read_anchor(anchor, project)
        path = File.expand_path(anchor["file"], project)
        raise Refusal, "There is no file #{anchor["file"]}" unless File.file?(path)

        lines = File.readlines(path, chomp: true)
        first = anchor["start"]
        last = anchor.fetch("end", first)
        unless first <= last && last <= lines.length
          raise Refusal, "#{anchor["file"]} has #{lines.length} lines, so no lines #{first}-#{last}"
        end
        { "file" => path, "start" => first, "end" => last, "text" => lines[(first - 1)..(last - 1)].join("\n") }
      end
    end

    # Shows Claude the open questions.
    class GetQuestions < AgendaTool
      tool_name "get_questions"
      description "Show the questions that still wait for the user's answer"
      input_schema(properties: {})

      def self.call(server_context:)
        respond do
          state = current_session_state(server_context)
          Formatter.questions_outline(state.agenda, project: state.project)
        end
      end
    end

    # Puts questions on the agenda, shaped like AskUserQuestion's, except
    # that the user answers in the cockpit whenever it suits them.
    class Ask < AgendaTool
      tool_name "ask"
      description "Ask the user questions in their session cockpit. Works like your AskUserQuestion tool, " \
                  "but takes any number of questions in one call and does not wait: the user answers when " \
                  "it suits them, and their submitted answers arrive later as an event of the submissions " \
                  "monitor. While the session's cockpit is on, ask here rather than with AskUserQuestion."
      input_schema(
        properties: {
          questions: { type: "array", minItems: 1,
                       items: { type: "object", properties: QUESTION_PROPERTIES, required: %w[question] } }
        },
        required: %w[questions]
      )

      def self.call(questions:, server_context:)
        respond do
          questions = plain(questions)
          questions.each { check_question(it) }
          questions = questions.map { with_anchors_read(it, server_context) }
          events = log_events(server_context) do |agenda|
            questions.zip(agenda.next_question_ids(questions.length)).map do |question, id|
              { "type" => "question_asked", "id" => id,
                **question.slice("question", "options", "multiSelect", "anchors") }
            end
          end
          "Asked #{events.map { it["id"] }.join(", ")}"
        end
      end
    end

    # Changes open questions. What a change leaves out stays as it was.
    class UpdateQuestions < AgendaTool
      tool_name "update_questions"
      description "Rewrite open questions whose wording, options or anchors what you learned since made " \
                  "out of date. What a change leaves out stays as it was."
      input_schema(
        properties: {
          questions: { type: "array", minItems: 1,
                       items: { type: "object", properties: { id: ID_SCHEMA, **QUESTION_PROPERTIES },
                                required: %w[id] } }
        },
        required: %w[questions]
      )

      def self.call(questions:, server_context:)
        respond do
          changes = plain(questions)
          changes.each { check_question(it) }
          changes = changes.map { with_anchors_read(it, server_context) }
          log_events(server_context) do |agenda|
            changes.map do |change|
              agenda.require_open_question(change["id"])
              { "type" => "question_updated", **change }
            end
          end
          "Updated #{changes.map { it["id"] }.join(", ")}"
        end
      end
    end

    # Takes back open questions that no longer need an answer.
    class WithdrawQuestions < AgendaTool
      tool_name "withdraw_questions"
      description "Take back open questions that no longer need the user's answer"
      input_schema(
        properties: { ids: { type: "array", minItems: 1, items: ID_SCHEMA } },
        required: %w[ids]
      )

      def self.call(ids:, server_context:)
        respond do
          log_events(server_context) do |agenda|
            ids.map do |id|
              agenda.require_open_question(id)
              { "type" => "question_withdrawn", "id" => id }
            end
          end
          "Withdrew #{ids.join(", ")}"
        end
      end
    end
  end
end
