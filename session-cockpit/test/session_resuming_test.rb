# frozen_string_literal: true

require "test_helper"

# Quitting Claude Code and resuming the session later with --resume.
class SessionResumingTest < SessionCockpit::SystemTestCase
  def test_after_resuming_only_submissions_claude_has_not_seen_reach_it
    session = start_session
    session.submit_from_dashboard("Seen before quitting")
    session.flush_watch_output

    session.quit
    session.submit_from_dashboard("Sent while Claude Code was closed")
    session.resume
    session.start_cockpit

    assert_equal <<~MARKDOWN, session.flush_watch_output
      **Dashboard submit**
      Comment: Sent while Claude Code was closed
    MARKDOWN
  end
end
