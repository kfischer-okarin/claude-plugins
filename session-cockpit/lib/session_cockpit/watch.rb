# frozen_string_literal: true

module SessionCockpit
  # The monitor: delivers what the user submits to Claude, following the
  # Claude Code process into a new session after /clear.
  module Watch
    def self.run(repository:, claude_pid:, initial_session_id:, out: $stdout)
      out.sync = true
      repository.record_monitor(claude_pid: claude_pid)
      loop do
        repository.current_session_state(claude_pid: claude_pid, fallback: initial_session_id)
                  .deliver_new_submissions(out)
        sleep 0.1
      end
    end
  end
end
