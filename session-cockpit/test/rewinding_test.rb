# frozen_string_literal: true

require "test_helper"

# Rewinding the conversation with /rewind takes back what Claude did after
# that point, and the cockpit follows: what the transcript no longer
# contains is left out of the agenda.
class RewindingTest < SessionCockpit::SystemTestCase
  def test_questions_asked_in_a_rewound_part_leave_the_agenda
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.prompt("Now the naming")
    session.call_mcp_tool("ask", questions: [question("Which name?", options: ["events", "log"])])

    session.rewind_to_before("Now the naming")
    session.prompt("Let's do the naming later")

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] JSON lines or SQLite?
        1. JSON lines — JSON lines.
        2. SQLite — SQLite.
    TEXT
  end

  def test_a_withdrawal_in_a_rewound_part_is_undone
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.prompt("Never mind the storage")
    session.call_mcp_tool("withdraw_questions", ids: ["q1"])

    session.rewind_to_before("Never mind the storage")
    session.prompt("Go on")

    assert_equal "open", session.call_mcp_tool("get_questions").then { session.agenda["questions"].first["status"] }
  end

  def test_an_update_in_a_rewound_part_is_undone
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.prompt("Ask about Postgres instead")
    session.call_mcp_tool("update_questions", questions: [{ id: "q1", question: "JSON lines or Postgres?" }])

    session.rewind_to_before("Ask about Postgres instead")
    session.prompt("Go on")

    assert_equal "JSON lines or SQLite?",
                 session.call_mcp_tool("get_questions").then { session.agenda["questions"].first["question"] }
  end

  def test_questions_asked_after_a_rewind_get_ids_not_handed_out_before
    session = start_session
    session.prompt("Now the naming")
    session.call_mcp_tool("ask", questions: [question("Which name?", options: ["events", "log"])])
    session.rewind_to_before("Now the naming")
    session.prompt("Let's name it differently")

    reply = session.call_mcp_tool("ask", questions: [question("Which prefix?", options: ["sc", "cockpit"])])

    assert_equal "Asked q2", reply
  end

  def test_answers_submitted_in_a_rewound_part_are_restored_for_the_user
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.prompt("I'll answer in the cockpit")
    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["SQLite"], text: "Queries matter" }])
    session.flush_watch_output

    session.rewind_to_before("I'll answer in the cockpit")
    session.prompt("Go on")

    assert_equal [["open", { "selected" => ["SQLite"], "text" => "Queries matter" }]],
                 session.call_mcp_tool("get_questions").then {
                   session.agenda["questions"].map { it.values_at("status", "restored_answer") }
                 }
  end

  def test_answers_submitted_before_the_point_rewound_to_stay
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["SQLite"] }])
    session.flush_watch_output
    session.prompt("Now the naming")

    session.rewind_to_before("Now the naming")
    session.prompt("Go on")

    assert_equal ["answered"], session.call_mcp_tool("get_questions").then {
      session.agenda["questions"].map { it["status"] }
    }
  end

  def test_the_next_submit_clears_restored_answers
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.prompt("I'll answer in the cockpit")
    session.submit_from_dashboard("", answers: [{ id: "q1", selected: ["SQLite"] }])
    session.flush_watch_output
    session.rewind_to_before("I'll answer in the cockpit")
    session.prompt("Go on")
    session.call_mcp_tool("get_questions")

    session.submit_from_dashboard("Later")

    assert_nil session.agenda["questions"].first["restored_answer"]
  end

  def test_questions_asked_before_a_compaction_stay
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.compact
    session.prompt("Go on")

    assert_equal ["JSON lines or SQLite?"], session.call_mcp_tool("get_questions").then {
      session.agenda["questions"].map { it["question"] }
    }
  end

  def test_questions_asked_together_with_another_tool_call_stay
    session = start_session
    session.prompt("Plan the storage")

    session.call_mcp_tool_together_with_another_tool(
      "ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])]
    )
    session.prompt("Go on")

    assert_equal ["JSON lines or SQLite?"], session.call_mcp_tool("get_questions").then {
      session.agenda["questions"].map { it["question"] }
    }
  end

  def test_a_branch_keeps_the_questions_and_the_cockpit
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    session.branch

    assert_equal <<~TEXT, session.call_mcp_tool("get_questions")
      [q1] JSON lines or SQLite?
        1. JSON lines — JSON lines.
        2. SQLite — SQLite.
    TEXT
  end

  def test_a_session_forked_in_a_new_process_keeps_the_questions_and_tells_claude_to_start_the_cockpit
    session = start_session
    session.prompt("Plan the storage")
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    told = session.fork_session

    assert_equal [<<~TOLD, "open"], [told, session.agenda["questions"].first["status"]]
      This session uses the session cockpit, whose monitor does not run yet since Claude Code started again. Run the start-cockpit skill now, so the user's answers reach you.
    TOLD
  end
end
