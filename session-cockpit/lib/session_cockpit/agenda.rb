# frozen_string_literal: true

module SessionCockpit
  # A session's agenda: the questions Claude asked the user, in the order
  # asked, shaped like Claude Code's AskUserQuestion. Built by replaying the
  # session's event log, leaving out what a rewind of the conversation took
  # back. QUESTION_COUNT and SUBMISSION_COUNT count every question asked and
  # every submission, rewound or not, so IDs are never handed out twice.
  Agenda = Data.define(:questions, :question_count, :submission_count) do
    def self.from_events(events)
      rewound = events.select { it["type"] == "rewound" }
      rewound_calls = rewound.flat_map { it.fetch("tool_use_ids", []) }.to_set
      rewound_submissions = rewound.flat_map { it.fetch("submissions", []) }.to_set
      events.reduce(new(questions: [], question_count: 0, submission_count: 0)) do |agenda, event|
        if rewound_calls.include?(event["tool_use_id"]) then agenda.skipping(event)
        elsif rewound_submissions.include?(event["id"]) && event["type"] == "submitted"
          agenda.restoring(event)
        else agenda.apply(event)
        end
      end
    end

    def apply(event)
      case event["type"]
      when "question_asked"
        with(questions: questions + [Question.from_event(event)], question_count: question_count + 1)
      when "question_updated" then changing_question(event["id"]) { it.updated_from(event) }
      when "question_withdrawn" then changing_question(event["id"]) { it.with(status: "withdrawn") }
      when "submitted"
        event["answers"].reduce(seen_by_user.with(submission_count: submission_count + 1)) do |agenda, answer|
          agenda.answering(answer)
        end
      when "rewound" then self
      end
    end

    # Leaves out EVENT, made by a tool call a rewind took back, but still
    # counts the questions it asked.
    def skipping(event)
      event["type"] == "question_asked" ? with(question_count: question_count + 1) : self
    end

    # Leaves out the submission EVENT, which a rewind took back from Claude,
    # and restores its answers on the questions still open, for the user to
    # submit again.
    def restoring(event)
      event["answers"].reduce(with(submission_count: submission_count + 1)) do |agenda, answer|
        agenda.changing_question(answer["id"]) do
          it.open? ? it.with(restored_answer: answer.slice("selected", "text")) : it
        end
      end
    end

    def next_submission_id = "s#{submission_count + 1}"

    def question(id) = questions.find { it.id == id }

    def open_questions = questions.select(&:open?)

    def require_open_question(id)
      question = question(id)
      raise Refusal, "There is no open question #{id}" unless question&.open?

      question
    end

    def next_question_ids(count) = (1..count).map { "q#{question_count + it}" }

    # The agenda as materialized into agenda.json for Emacs.
    def to_h
      { "questions" => questions.map(&:to_h) }
    end

    # Nothing is new anymore once the user has submitted, and restored
    # answers were submitted again or dropped.
    def seen_by_user
      with(questions: questions.map { it.with(new: false, changed: false, restored_answer: nil) })
    end

    # Records the user's ANSWER; one to a question no longer open leaves the
    # agenda as it is.
    def answering(answer)
      changing_question(answer["id"]) do
        it.open? ? it.with(status: "answered", answer: answer.slice("selected", "text")) : it
      end
    end

    # Changes a question through the block; an unknown question leaves the
    # agenda as it is.
    def changing_question(id, &change)
      with(questions: questions.map { it.id == id ? change.(it) : it })
    end
  end

  # A question without options is answered in free text. ANCHORS are the
  # places in the project's files it points at, each a file, a line range and
  # the text of those lines when Claude asked. NEW means Claude asked it after
  # the user's last submit; CHANGED means Claude changed it after the user's
  # last submit, and it is not new anyway. RESTORED_ANSWER is what the user
  # had answered in a submission a rewind took back.
  Question = Data.define(:id, :text, :options, :multi_select, :anchors, :status, :answer, :new, :changed,
                         :restored_answer) do
    def self.from_event(event)
      new(id: event["id"], text: event["question"], options: event.fetch("options", []),
          multi_select: event["multiSelect"] == true, anchors: event.fetch("anchors", []),
          status: "open", answer: nil, new: true, changed: false, restored_answer: nil)
    end

    def open? = status == "open"

    # Takes over what EVENT changes; what it leaves out stays as it was.
    def updated_from(event)
      with(text: event.fetch("question", text), options: event.fetch("options", options),
           multi_select: event.fetch("multiSelect", multi_select), anchors: event.fetch("anchors", anchors),
           changed: !new)
    end

    def to_h
      { "id" => id, "question" => text, "options" => options, "multiSelect" => multi_select,
        "anchors" => (anchors unless anchors.empty?), "status" => status, "answer" => answer,
        "new" => (true if new), "changed" => (true if changed), "restored_answer" => restored_answer }.compact
    end
  end

  # An operation that would make the agenda inconsistent. Raised before
  # anything is logged.
  class Refusal < StandardError; end
end
