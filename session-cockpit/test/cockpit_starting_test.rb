# frozen_string_literal: true

require "test_helper"

# A session uses the cockpit once the start-cockpit skill turned it on, which
# also starts the monitor that brings the user's answers to Claude.
class CockpitStartingTest < SessionCockpit::SystemTestCase
  def test_starting_the_cockpit_tells_claude_it_is_on_and_what_is_open
    session = start_session_without_cockpit

    output = session.start_cockpit

    assert_equal <<~TEXT, output
      The cockpit is on for this session. The user opens it in Emacs with M-x session-cockpit-show.
      No open questions.
    TEXT
  end

  def test_starting_the_cockpit_again_after_resuming_shows_claude_the_open_questions
    session = start_session
    session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])
    session.quit
    session.resume

    output = session.start_cockpit

    assert_equal <<~TEXT, output
      The cockpit is on for this session. The user opens it in Emacs with M-x session-cockpit-show.
      [q1] JSON lines or SQLite?
        1. JSON lines — JSON lines.
        2. SQLite — SQLite.
    TEXT
  end

  def test_tools_refuse_in_a_session_whose_cockpit_is_not_on
    session = start_session_without_cockpit

    reply = session.call_mcp_tool("ask", questions: [question("JSON lines or SQLite?", options: ["JSON lines", "SQLite"])])

    assert_equal "The cockpit is not on for this session. Run the start-cockpit skill to turn it on.", reply
    refute File.exist?(File.join(@state_dir, session.id, "events.jsonl"))
  end

  def test_tools_refuse_while_no_monitor_runs_and_say_how_to_start_one
    session = start_session
    session.stop_monitor

    reply = session.call_mcp_tool("get_questions")

    assert_equal <<~TEXT.chomp, reply
      The monitor that brings the user's answers to you is not running. Run the start-cockpit skill to start it. If it ran already since Claude Code started, start this command with your Monitor tool instead, at the longest timeout, and start it again whenever it expires:
      CLAUDE_CODE_SESSION_ID=#{session.id} SESSION_COCKPIT_STATE_DIR=#{@state_dir} mise exec -C #{SessionCockpit::ROOT} -- #{SessionCockpit::EXE} watch
    TEXT
  end

  def test_after_clear_the_cockpit_is_off_until_started_again
    session = start_session

    session.clear
    reply = session.call_mcp_tool("get_questions")

    assert_equal "The cockpit is not on for this session. Run the start-cockpit skill to turn it on.", reply
  end

  def test_resuming_a_session_using_the_cockpit_tells_claude_to_start_it_again
    session = start_session
    session.quit

    told = session.resume

    assert_equal <<~TEXT, told
      This session uses the session cockpit, whose monitor does not run yet since Claude Code started again. Run the start-cockpit skill now, so the user's answers reach you.
    TEXT
  end

  def test_resuming_a_session_without_cockpit_tells_claude_nothing
    session = start_session_without_cockpit
    session.quit

    told = session.resume

    assert_equal "", told
  end
end
