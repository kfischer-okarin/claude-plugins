# frozen_string_literal: true

require "test_helper"

# After /clear, Claude Code keeps the plugin's MCP server and monitor running
# but continues under a new session ID.
class SessionSwitchingTest < SessionCockpit::SystemTestCase
  def test_after_clear_questions_go_to_the_new_session
    session = start_session
    session.call_mcp_tool("ask", questions: [question("Before the clear?", options: ["Yes", "No"])])

    session.clear
    session.start_cockpit
    session.call_mcp_tool("ask", questions: [question("Fresh start?", options: ["Yes", "No"])])

    assert_equal ["Fresh start?"], read_agenda(session.id)["questions"].map { it["question"] }
  end

  def test_after_clear_the_new_session_records_its_project
    session = start_session(project: "/Users/me/workspace/claude-plugins")

    session.clear

    assert_equal({ "project" => "/Users/me/workspace/claude-plugins" }, session.info)
  end

  def test_starting_a_session_forgets_claude_processes_that_have_ended
    ended_claude_pid = spawn("true").tap { Process.wait(it) }.to_s
    record_session_start_for(claude_pid: ended_claude_pid)

    start_session

    refute File.exist?(by_pid_file(ended_claude_pid))
  end

  def test_starting_a_session_keeps_claude_processes_still_running
    running_claude_pid = Process.pid.to_s
    record_session_start_for(claude_pid: running_claude_pid)

    start_session

    assert File.exist?(by_pid_file(running_claude_pid))
  end

  def test_after_clear_submissions_in_the_new_session_reach_claude
    session = start_session
    session.submit_from_dashboard("Before the clear")
    session.flush_watch_output

    session.clear
    session.submit_from_dashboard("After the clear")

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      Comment: After the clear
    MARKDOWN
  end
end
