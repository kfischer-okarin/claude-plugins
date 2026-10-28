# frozen_string_literal: true

require "test_helper"

# Emacs and this side meet at files: the agenda this side writes and the
# submissions Emacs puts into the inbox. Each scenario in contract_fixtures
# holds those files step by step, with what Claude and the user see of them;
# these tests hold this side to it, and the Emacs contract tests hold Emacs.
class ContractsTest < SessionCockpit::SystemTestCase
  def test_round_trip
    session = start_session(project: "/Users/me/workspace/claude-plugins")
    assert_equal contract_fixture("round_trip/01_session.json"), session.info
    session.call_mcp_tool("ask", questions: [
                            question("JSON lines or SQLite?", options: [
                                       { label: "JSON lines (Recommended)", description: "Greppable and append-only" },
                                       { label: "SQLite", description: "Queryable, but a dependency" }
                                     ]),
                            question("Which parts ship first?", multi_select: true, options: [
                                       { label: "Picker", description: "Lists the sessions" },
                                       { label: "Header", description: "Counts unsent answers" },
                                       { label: "Brief", description: "Recaps the session" }
                                     ]),
                            question("What should the log be called?", options: [
                                       { label: "events.jsonl", description: "Says what it holds",
                                         preview: "<state>/<session>/events.jsonl" },
                                       { label: "log.jsonl", description: "Short" }
                                     ])
                          ])
    assert_equal contract_fixture("round_trip/01_agenda.json"), session.agenda
    assert_equal contract_fixture("round_trip/01_get_questions.md"), session.call_mcp_tool("get_questions")

    session.submit_from_contract_fixture("round_trip/02_submission.json")
    assert_equal contract_fixture("round_trip/02_monitor.md"), session.flush_watch_output
    assert_equal contract_fixture("round_trip/03_agenda.json"), session.agenda
    assert_equal contract_fixture("round_trip/03_get_questions.md"), session.call_mcp_tool("get_questions")

    session.call_mcp_tool("update_questions", questions: [{ id: "q3", question: "What should the event log be called?" }])
    assert_equal contract_fixture("round_trip/04_agenda.json"), session.agenda
    assert_equal contract_fixture("round_trip/04_get_questions.md"), session.call_mcp_tool("get_questions")
  end

  def test_anchors
    project = copy_of_contract_project("anchors/project")
    session = start_session(project: project)
    session.call_mcp_tool("ask", questions: [
                            question("Should the watch also follow /clear?",
                                     options: [{ label: "Yes", description: "Look the session up on every poll" },
                                               { label: "No", description: "Restart it instead" }],
                                     anchors: [{ file: "lib/watch.rb", start: 3, end: 7 },
                                               { file: "README.md", start: 1 }])
                          ])
    assert_equal contract_fixture("anchors/01_agenda.json", project: project), session.agenda
    assert_equal contract_fixture("anchors/01_get_questions.md"), session.call_mcp_tool("get_questions")

    session.submit_from_contract_fixture("anchors/02_submission.json")
    assert_equal contract_fixture("anchors/02_monitor.md"), session.flush_watch_output
  end
end
