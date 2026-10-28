# frozen_string_literal: true

require "test_helper"

# What Claude reads back from its tool calls inside Claude Code.
class ToolFeedbackTest < SessionCockpit::SystemTestCase
  def test_asking_answers_with_the_ids
    session = start_session

    reply = session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"]),
                                                     question("Which name?", options: ["events", "log"])])

    assert_equal "Asked q1, q2", reply
  end

  def test_updating_answers_with_the_ids
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"]),
                                             question("Which name?", options: ["events", "log"])])

    reply = session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Keep JSON lines?" },
                                                                  { id: "q2", question: "Which file name?" }])

    assert_equal "Updated q1, q2", reply
  end

  def test_withdrawing_answers_with_the_ids
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"]),
                                             question("Which name?", options: ["events", "log"])])

    assert_equal "Withdrew q1, q2", session.call_mcp_tool("withdraw_questions", ids: %w[q1 q2])
  end

  def test_no_open_questions_says_so
    session = start_session

    assert_equal "No open questions.\n", session.call_mcp_tool("get_questions")
  end

  def test_the_questions_list_with_numbered_options
    session = start_session
    session.call_mcp_tool("ask", questions: [
                            question("JSON lines or SQLite?", options: [{ label: "JSON lines", description: "Greppable" },
                                                                        { label: "SQLite", description: "Queryable" }])
                          ])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] JSON lines or SQLite?
        1. JSON lines — Greppable
        2. SQLite — Queryable
    TEXT
  end

  def test_a_question_without_options_is_listed_alone
    session = start_session
    session.call_mcp_tool("ask", questions: [question("What should the log be called?")])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] What should the log be called?
    TEXT
  end

  def test_the_questions_say_when_several_options_may_be_picked
    session = start_session
    session.call_mcp_tool("ask", questions: [
                            question("Which parts ship first?", multi_select: true,
                                                                options: [{ label: "Picker", description: "Lists sessions" },
                                                                          { label: "Header", description: "Counts answers" }])
                          ])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] Which parts ship first? (multi-select)
        1. Picker — Lists sessions
        2. Header — Counts answers
    TEXT
  end

  def test_an_options_preview_lines_up_behind_its_number
    session = start_session
    session.call_mcp_tool("ask", questions: [
                            question("Which header?", options: [{ label: "Count", description: "Shows the count",
                                                                  preview: "2 unsent\nSubmit" },
                                                                { label: "Plain", description: "Only Submit" }])
                          ])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] Which header?
        1. Count — Shows the count
           2 unsent
           Submit
        2. Plain — Only Submit
    TEXT
  end

  def test_further_lines_of_a_question_continue_behind_its_id
    session = start_session
    session.call_mcp_tool("ask", questions: [
                            question("JSON lines or SQLite?\nBoth work.",
                                     options: [{ label: "JSON lines", description: "Greppable" },
                                               { label: "SQLite", description: "Queryable" }])
                          ])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] JSON lines or SQLite?
           Both work.
        1. JSON lines — Greppable
        2. SQLite — Queryable
    TEXT
  end

  def test_the_places_a_question_points_at_are_listed_below_it
    session = start_session(project: create_project("lib/watch.rb" => "module Watch\n  def self.run\n  end\nend\n"))
    session.call_mcp_tool("ask", questions: [
                            question("Should this also handle /clear?",
                                     options: [{ label: "Yes", description: "Follow /clear" },
                                               { label: "No", description: "Restart instead" }],
                                     anchors: [{ file: "lib/watch.rb", start: 2, end: 3 },
                                               { file: "lib/watch.rb", start: 1 }])
                          ])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] Should this also handle /clear?
           ⌖ lib/watch.rb:2-3
           ⌖ lib/watch.rb:1
        1. Yes — Follow /clear
        2. No — Restart instead
    TEXT
  end

  def test_places_outside_the_project_are_listed_with_their_full_path_home_as_tilde
    in_home = create_project_within(Dir.home, "zshrc" => "export EDITOR=emacsclient\n")
    elsewhere = create_project("hosts" => "127.0.0.1 localhost\n")
    session = start_session(project: create_project("lib/watch.rb" => "module Watch\nend\n"))
    session.call_mcp_tool("ask", questions: [
                            question("Keep these?", anchors: [{ file: "#{in_home}/zshrc", start: 1 },
                                                              { file: "#{elsewhere}/hosts", start: 1 }])
                          ])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] Keep these?
           ⌖ ~/#{File.basename(in_home)}/zshrc:1
           ⌖ #{elsewhere}/hosts:1
    TEXT
  end

  def test_answered_and_withdrawn_questions_are_left_out
    session = start_session
    session.call_mcp_tool("ask", questions: [
                            question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"]),
                            question("Rename the log?", options: ["Yes", "No"]),
                            question("Which parts ship first?", options: [{ label: "Picker", description: "Lists sessions" },
                                                                          { label: "Header", description: "Counts answers" }])
                          ])
    session.call_mcp_tool("withdraw_questions", ids: ["q2"])
    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["SQLite"] }])

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q3] Which parts ship first?
        1. Picker — Lists sessions
        2. Header — Counts answers
    TEXT
  end
end
