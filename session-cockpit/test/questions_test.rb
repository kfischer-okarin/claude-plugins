# frozen_string_literal: true

require "test_helper"

# The questions Claude asks the user, shaped like AskUserQuestion's.
class QuestionsTest < SessionCockpit::SystemTestCase
  def test_questions_get_ids_in_the_order_they_are_asked
    session = start_session

    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.call_mcp_tool("ask", questions: [question("Which name?", options: ["events", "log"])])

    assert_equal [["q1", "JSON lines or SQLite?"], ["q2", "Which name?"]],
                 session.agenda["questions"].map { it.values_at("id", "question") }
  end

  def test_one_call_can_ask_any_number_of_questions
    session = start_session

    session.call_mcp_tool("ask", questions: (1..5).map { question("Question #{it}?", options: ["Yes", "No"]) })

    assert_equal %w[q1 q2 q3 q4 q5], session.agenda["questions"].map { it["id"] }
  end

  def test_a_question_keeps_its_options_and_whether_several_may_be_picked
    session = start_session

    session.call_mcp_tool("ask", questions: [
                            question("Which parts ship first?", multi_select: true, options: [
                                       { label: "Picker", description: "Lists sessions" },
                                       { label: "Header", description: "Counts answers", preview: "2 unsent  Submit" }
                                     ])
                          ])

    assert_equal [[{ "label" => "Picker", "description" => "Lists sessions" },
                   { "label" => "Header", "description" => "Counts answers", "preview" => "2 unsent  Submit" }],
                  true],
                 session.agenda["questions"].first.values_at("options", "multiSelect")
  end

  def test_a_question_without_options_is_asked_for_free_text
    session = start_session

    session.call_mcp_tool("ask", questions: [{ question: "What should the log be called?" }])

    assert_equal [[], false], session.agenda["questions"].first.values_at("options", "multiSelect")
  end

  def test_new_questions_are_open
    session = start_session

    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    assert_equal "open", session.agenda["questions"].first["status"]
  end

  def test_a_question_asked_after_the_last_submit_is_marked_new
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.submit_from_dashboard("Noted")

    session.call_mcp_tool("ask", questions: [question("Which name?", options: ["events", "log"])])

    assert_equal [["q1", nil], ["q2", true]], session.agenda["questions"].map { it.values_at("id", "new") }
  end

  def test_a_question_with_a_single_option_is_refused_and_nothing_is_asked
    session = start_session

    reply = session.call_mcp_tool("ask", questions: [
                                    question("Which name?", options: ["events", "log"]),
                                    question("JSON lines?", options: ["Yes"])
                                  ])
    session.call_mcp_tool("ask", questions: [question("Rename it?", options: ["Yes", "No"])])

    assert_equal "A question has 2 to 4 options, or none: JSON lines?", reply
    assert_equal [["q1", "Rename it?"]], session.agenda["questions"].map { it.values_at("id", "question") }
  end

  def test_a_question_with_more_than_four_options_is_refused
    session = start_session

    reply = session.call_mcp_tool("ask", questions: [question("Which name?", options: %w[a b c d e])])

    assert_equal "Invalid arguments: array size at `/questions/0/options` is greater than: 4", reply
  end

  def test_repeated_option_labels_are_refused
    session = start_session

    reply = session.call_mcp_tool("ask", questions: [question("Which name?", options: ["events", "events"])])

    assert_equal "Option labels repeat: events, events", reply
  end

  def test_an_update_changes_only_what_it_names
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Keep JSON lines?" }])

    assert_equal ["Keep JSON lines?", ["JSON lines", "SQLite"]],
                 session.agenda["questions"].first.then { [it["question"], it["options"].map { it["label"] }] }
  end

  def test_one_call_can_update_several_questions
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"]),
                                             question("Which name?", options: ["events", "log"])])

    session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Keep JSON lines?" },
                                                          { id: "q2", options: [] }])

    assert_equal [["Keep JSON lines?", 2], ["Which name?", 0]],
                 session.agenda["questions"].map { [it["question"], it["options"].length] }
  end

  def test_a_question_changed_after_the_last_submit_is_marked_changed
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.submit_from_dashboard("Noted")

    session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Keep JSON lines?" }])

    assert_equal true, session.agenda["questions"].first["changed"]
  end

  def test_a_new_question_changed_is_only_marked_new
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Keep JSON lines?" }])

    assert_equal [true, nil], session.agenda["questions"].first.values_at("new", "changed")
  end

  def test_an_update_breaking_the_question_shape_is_refused
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    reply = session.call_mcp_tool("update_questions",
                                  questions: [{ id: "q1", options: [{ label: "Yes", description: "Keep" }] }])

    assert_equal "A question has 2 to 4 options, or none: q1", reply
    assert_equal ["JSON lines", "SQLite"], session.agenda["questions"].first["options"].map { it["label"] }
  end

  def test_an_update_naming_a_question_not_open_is_refused_as_a_whole
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    reply = session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Keep JSON lines?" },
                                                                  { id: "q9", question: "Lost?" }])

    assert_equal "There is no open question q9", reply
    assert_equal "JSON lines or SQLite?", session.agenda["questions"].first["question"]
  end

  def test_updating_an_answered_question_is_refused
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["JSON lines"] }])

    reply = session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "Too late?" }])

    assert_equal "There is no open question q1", reply
  end

  def test_withdrawn_questions_are_no_longer_open
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"]),
                                             question("Which name?", options: ["events", "log"])])

    session.call_mcp_tool("withdraw_questions", ids: %w[q1 q2])

    assert_equal %w[withdrawn withdrawn], session.agenda["questions"].map { it["status"] }
  end

  def test_withdrawing_a_question_not_open_is_refused_as_a_whole
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    reply = session.call_mcp_tool("withdraw_questions", ids: %w[q1 q9])

    assert_equal "There is no open question q9", reply
    assert_equal "open", session.agenda["questions"].first["status"]
  end
end
