# frozen_string_literal: true

require "test_helper"

# What the user sends from the dashboard in one go: how it is printed for
# Claude, and what it does to the agenda.
class SubmissionsTest < SessionCockpit::SystemTestCase
  def test_a_picked_option_is_printed_under_its_question
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["JSON lines"] }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] JSON lines or SQLite?
        → JSON lines
    MARKDOWN
  end

  def test_several_picked_options_are_printed_together
    session = start_session
    session.call_mcp_tool("ask", questions: [question("Which parts ship first?", multi_select: true,
                                                                                 options: %w[Picker Header Brief])])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: %w[Picker Header] }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] Which parts ship first?
        → Picker, Header
    MARKDOWN
  end

  def test_the_text_answering_a_question_without_options_is_printed_as_the_answer
    session = start_session
    session.call_mcp_tool("ask", questions: [question("What should the log be called?")])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: [], text: "history" }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] What should the log be called?
        Answer: history
    MARKDOWN
  end

  def test_text_without_a_picked_option_is_printed_as_other
    session = start_session
    session.call_mcp_tool("ask", questions: [question("Which name?", options: ["events", "log"])])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: [], text: "history" }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] Which name?
        Other: history
    MARKDOWN
  end

  def test_text_with_a_picked_option_is_printed_as_a_note
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["JSON lines"], text: "Keep it greppable" }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] JSON lines or SQLite?
        → JSON lines
        Note: Keep it greppable
    MARKDOWN
  end

  def test_further_lines_of_the_text_continue_behind_its_label
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["JSON lines"],
                                                  text: "Keep it greppable\nand append-only" }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] JSON lines or SQLite?
        → JSON lines
        Note: Keep it greppable
              and append-only
    MARKDOWN
  end

  def test_the_comment_is_printed_after_the_answers
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.submit_from_dashboard("Go ahead", answers: [{ id: "q1", selected: ["JSON lines"] }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      [q1] JSON lines or SQLite?
        → JSON lines
      Comment: Go ahead
    MARKDOWN
  end

  def test_places_no_longer_in_the_users_files_are_printed_before_the_comment
    project = create_project("lib/watch.rb" => "module Watch\n  def self.run\n  end\nend\n")
    session = start_session(project: project)
    session.call_mcp_tool("ask", questions: [
                            question("Should this also handle /clear?",
                                     anchors: [{ file: "lib/watch.rb", start: 2, end: 3 }])
                          ])

    session.submit_from_dashboard("Go ahead", lost_anchors: [{ id: "q1", file: "#{project}/lib/watch.rb",
                                                               start: 2, end: 3 }])

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      ⚠ [q1] lib/watch.rb:2-3 is not in the file anymore
      Comment: Go ahead
    MARKDOWN
  end

  def test_an_answer_makes_its_question_answered_and_keeps_the_answer
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["JSON lines"], text: "Keep it greppable" }])

    assert_equal ["answered", { "selected" => ["JSON lines"], "text" => "Keep it greppable" }],
                 session.agenda["questions"].first.values_at("status", "answer")
  end

  def test_an_answer_to_a_withdrawn_question_leaves_it_withdrawn
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.call_mcp_tool("withdraw_questions", ids: ["q1"])

    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["JSON lines"] }])

    assert_equal "withdrawn", session.agenda["questions"].first["status"]
  end
end
