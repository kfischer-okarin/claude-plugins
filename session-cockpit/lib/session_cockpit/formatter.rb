# frozen_string_literal: true

module SessionCockpit
  # How Claude sees the agenda and what the user submits. No empty lines
  # anywhere, since monitor output drops them.
  module Formatter
    # What the start-cockpit skill tells Claude: that the cockpit is on, and
    # the questions open in it, since a resumed session has some already.
    def self.cockpit_on(agenda, project:)
      "The cockpit is on for this session. The user opens it in Emacs with M-x session-cockpit-show.\n" \
        "#{questions_outline(agenda, project: project)}"
    end

    # The open questions as Claude reads them: ID and question, the places it
    # points at, then the numbered options with their descriptions and
    # previews below. Further lines of a question and its places continue
    # behind its ID, a preview's lines behind its option's number.
    def self.questions_outline(agenda, project:)
      questions = agenda.open_questions
      return "No open questions.\n" if questions.empty?

      questions.flat_map { |question|
        label = "[#{question.id}] "
        first, *rest = question.text.lines(chomp: true)
        multi_select = " (multi-select)" if question.multi_select
        [
          "#{label}#{first}#{multi_select}",
          *rest.map { "#{" " * label.length}#{it}" },
          *question.anchors.map { "#{" " * label.length}⌖ #{anchor_reference(it, project)}" },
          *question.options.each_with_index.flat_map { |option, index| option_lines(option, index + 1) }
        ]
      }.map { "#{it}\n" }.join
    end

    def self.option_lines(option, number)
      description = " — #{option["description"]}" unless option["description"].to_s.empty?
      ["  #{number}. #{option["label"]}#{description}",
       *option["preview"]&.lines(chomp: true)&.map { "     #{it}" }]
    end

    # A submission as Claude reads it: each answer under its question, the
    # places questions point at that the user's files no longer have, then
    # the comment. Free text is the answer to a question without options; it
    # reads as Other when no option was picked, and as a note on the pick
    # otherwise.
    def self.submission(event, agenda, project:)
      lines = ["**Dashboard submit**"]
      event["answers"].each { lines.concat(answer_lines(it, agenda)) }
      event.fetch("lost_anchors", []).each do
        lines << "⚠ [#{it["id"]}] #{anchor_reference(it, project)} is not in the file anymore"
      end
      lines << "Comment: #{event["comment"]}" unless event["comment"].to_s.empty?
      lines.map { "#{it}\n" }.join
    end

    def self.answer_lines(answer, agenda)
      selected = Array(answer["selected"])
      question = agenda.question(answer["id"])
      lines = ["[#{answer["id"]}] #{question&.text&.lines&.first&.chomp || "(unknown question)"}"]
      lines << "  → #{selected.join(", ")}" unless selected.empty?
      unless answer["text"].to_s.empty?
        label = if question && question.options.empty? then "Answer: "
                elsif selected.empty? then "Other: "
                else "Note: "
                end
        first, *rest = answer["text"].lines(chomp: true)
        lines << "  #{label}#{first}"
        rest.each { lines << "  #{" " * label.length}#{it}" }
      end
      lines
    end

    # A file and line range, as in lib/watch.rb:2-3, or lib/watch.rb:2 for a
    # single line. The file is relative to PROJECT when within it, and
    # starts with ~ when within the home directory otherwise.
    def self.anchor_reference(anchor, project)
      lines = anchor["start"] == anchor["end"] ? anchor["start"] : "#{anchor["start"]}-#{anchor["end"]}"
      "#{shown_path(anchor["file"], project)}:#{lines}"
    end

    def self.shown_path(path, project)
      if path.start_with?("#{project}/") then path.delete_prefix("#{project}/")
      elsif path.start_with?("#{Dir.home}/") then path.sub(Dir.home, "~")
      else path
      end
    end
  end
end
