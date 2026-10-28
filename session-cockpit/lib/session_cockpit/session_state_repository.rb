# frozen_string_literal: true

module SessionCockpit
  # Where the state of every Claude Code session lives, one directory per
  # session, and which session each Claude Code process is in now.
  class SessionStateRepository
    def initialize(path)
      @path = path
    end

    # The state of the session the Claude Code process with CLAUDE_PID is in
    # now, or of FALLBACK until its SessionStart hook has told.
    def current_session_state(claude_pid:, fallback:)
      by_pid_path = by_pid_path(claude_pid)
      session_state(File.exist?(by_pid_path) ? File.read(by_pid_path) : fallback)
    end

    def session_state(session_id)
      SessionState.new(File.join(@path, session_id))
    end

    # Remembers which session the Claude Code process is in now, since /clear
    # switches sessions without restarting the MCP server or the monitor, and
    # the session's PROJECT, and returns the session's state. Forgets
    # processes that have ended along the way.
    def record_session_start(claude_pid:, session_id:, project:)
      forget_ended_claude_processes
      path = by_pid_path(claude_pid)
      FileUtils.mkdir_p(File.dirname(path))
      AtomicFile.write(path, session_id)
      session_state(session_id).tap { it.record_project(project) }
    end

    # Remembers that this process is the monitor of the Claude Code process
    # with CLAUDE_PID, which then knows whether its monitor runs.
    def record_monitor(claude_pid:)
      path = monitor_path(claude_pid)
      FileUtils.mkdir_p(File.dirname(path))
      AtomicFile.write(path, Process.pid.to_s)
    end

    def monitor_running?(claude_pid:)
      path = monitor_path(claude_pid)
      File.exist?(path) && process_alive?(File.read(path).to_i)
    end

    private

    def forget_ended_claude_processes
      Dir.glob(by_pid_path("*")).each do |path|
        pid = File.basename(path)[/\A(\d+)(\.monitor)?\z/, 1]
        File.delete(path) if pid && !process_alive?(pid.to_i)
      end
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def by_pid_path(claude_pid)
      File.join(@path, "by-pid", claude_pid.to_s)
    end

    def monitor_path(claude_pid)
      "#{by_pid_path(claude_pid)}.monitor"
    end
  end
end
