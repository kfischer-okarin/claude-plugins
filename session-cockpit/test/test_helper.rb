# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "securerandom"
require "tmpdir"

module SessionCockpit
  ROOT = File.expand_path("..", __dir__)
  EXE = File.join(ROOT, "exe/session-cockpit")
  # Scenarios of what Emacs and Claude Code's side exchange, step by step.
  CONTRACT_FIXTURES = File.expand_path("../contract_fixtures", __dir__)

  # The text of the contract fixture at PATH, with <project> standing for
  # PROJECT, since absolute paths differ from run to run.
  def self.contract_fixture_content(path, project:)
    content = File.read(File.join(CONTRACT_FIXTURES, path))
    project ? content.gsub("<project>", project) : content
  end

  # Runs the real `session-cockpit` executable as subprocesses against a
  # temporary state directory.
  class SystemTestCase < Minitest::Test
    def before_setup
      super
      @state_dir = Dir.mktmpdir
      @sessions = []
      @projects = []
    end

    def after_teardown
      @sessions.each(&:stop)
      FileUtils.rm_rf([@state_dir, *@projects])
      super
    end

    # A temporary project directory holding FILES, a hash from path to
    # content, and returns its path.
    def create_project(files)
      create_project_within(Dir.tmpdir, files)
    end

    # A temporary project directory within DIRECTORY holding FILES, a hash
    # from path to content, and returns its path.
    def create_project_within(directory, files)
      Dir.mktmpdir("session-cockpit-test-", directory).tap do |project|
        @projects << project
        files.each do |path, content|
          FileUtils.mkdir_p(File.dirname(File.join(project, path)))
          File.write(File.join(project, path), content)
        end
      end
    end

    # A temporary copy of the project in the contract fixture at PATH, so a
    # scenario can change its files.
    def copy_of_contract_project(path)
      create_project({}).tap { FileUtils.cp_r("#{File.join(CONTRACT_FIXTURES, path)}/.", it) }
    end

    # Starts a session in PROJECT, the directory Claude Code runs in, and
    # turns its cockpit on.
    def start_session(project: "/Users/me/workspace/some-project")
      start_session_without_cockpit(project: project).tap(&:start_cockpit)
    end

    # Starts a session in PROJECT whose cockpit nobody turned on.
    def start_session_without_cockpit(project: "/Users/me/workspace/some-project")
      TestSession.start(env: cli_env, project: project).tap { @sessions << it }
    end

    def read_agenda(session_id)
      JSON.parse(File.read(File.join(@state_dir, session_id, "agenda.json")))
    end

    # A question as the ask tool takes it. OPTIONS are labels, each described
    # as itself, or full option hashes; without any, the question is answered
    # in free text. ANCHORS are places in the project's files, if any.
    def question(text, options: [], multi_select: false, anchors: nil)
      { question: text, multiSelect: multi_select,
        options: options.map { it.is_a?(Hash) ? it : { label: it, description: "#{it}." } },
        anchors: anchors }.compact
    end

    # The contract fixture at PATH: parsed if it is JSON, as text otherwise.
    # <project> in it stands for PROJECT, the directory the session runs in.
    def contract_fixture(path, project: nil)
      content = SessionCockpit.contract_fixture_content(path, project: project)
      path.end_with?(".json") ? JSON.parse(content) : content
    end

    # Runs the SessionStart hook as the Claude Code process CLAUDE_PID would.
    def record_session_start_for(claude_pid:)
      input = JSON.generate(session_id: SecureRandom.uuid, source: "startup", cwd: "/Users/me/workspace/some-project")
      output, status = Open3.capture2e(cli_env.merge("CLAUDE_PID" => claude_pid), EXE, "session-start",
                                       stdin_data: input)
      assert status.success?, output
    end

    # Where the session a Claude Code process is in gets recorded.
    def by_pid_file(claude_pid)
      File.join(@state_dir, "by-pid", claude_pid)
    end

    private

    def cli_env
      { "SESSION_COCKPIT_STATE_DIR" => @state_dir }
    end
  end

  # A Claude Code session as the plugin sees it: an MCP server started for
  # the session, and the watch process its cockpit starts.
  class TestSession
    TIMEOUT = 5
    QUIET_PERIOD = 0.3

    attr_reader :id

    def self.start(env:, project:)
      new(id: SecureRandom.uuid, env: env, project: project).tap(&:start)
    end

    def initialize(id:, env:, project:)
      @id = id
      @base_env = env
      @project = project
      @next_request_id = 0
    end

    def start
      launch_claude_code(source: "startup")
    end

    # Continues under a new session ID, as Claude Code does on /clear.
    def clear
      @id = SecureRandom.uuid
      run_session_start_hook(source: "clear")
    end

    # Runs the start-cockpit skill, which turns the cockpit on and starts the
    # monitor, once per Claude Code process like a plugin monitor started on
    # a skill. Returns what the skill tells Claude.
    def start_cockpit
      output, status = Open3.capture2e(@env, EXE, "start", id)
      raise "session-cockpit start failed:\n#{output}" unless status.success?

      unless @watch
        @watch = ChildProcess.spawn(@env, EXE, "watch")
        wait_until { File.exist?(File.join(state_dir, "by-pid", "#{@claude_pid}.monitor")) }
      end
      output
    end

    # Stops the monitor, as when it crashed.
    def stop_monitor
      @watch.stop
    end

    # Quits Claude Code, which stops the MCP server and the monitor.
    def quit
      stop
      @mcp = @watch = nil
    end

    # Starts Claude Code again on this session, as `claude --resume` does,
    # and returns what the SessionStart hook tells Claude.
    def resume
      launch_claude_code(source: "resume")
    end

    # Calls the tool NAME on the MCP server and returns the reply text Claude
    # would read.
    def call_mcp_tool(name, **arguments)
      request("tools/call", name: name, arguments: arguments)["content"].map { it["text"] }.join
    end

    # Submits COMMENT, ANSWERS and the LOST_ANCHORS Emacs could not find
    # anymore the way the Emacs dashboard does: as a file of its own in the
    # session's inbox, named so that the inbox sorts by time. While Claude
    # Code runs, waits until the MCP server has taken it over.
    def submit_from_dashboard(comment, answers: [], lost_anchors: nil)
      put_into_inbox(JSON.generate({ type: "submitted", comment: comment, answers: answers,
                                     lost_anchors: lost_anchors }.compact))
    end

    # Submits the contract fixture at PATH, as the Emacs dashboard would have
    # written it in this session's project.
    def submit_from_contract_fixture(path)
      put_into_inbox(SessionCockpit.contract_fixture_content(path, project: @project))
    end

    # The agenda as the MCP server materialized it for Emacs.
    def agenda
      JSON.parse(File.read(File.join(@base_env.fetch("SESSION_COCKPIT_STATE_DIR"), id, "agenda.json")))
    end

    # What the session recorded about itself for Emacs.
    def info
      JSON.parse(File.read(File.join(@base_env.fetch("SESSION_COCKPIT_STATE_DIR"), id, "session.json")))
    end

    def flush_watch_output
      @watch.read_until_quiet(timeout: TIMEOUT, quiet_period: QUIET_PERIOD)
    end

    def stop
      [@mcp, @watch, @claude].compact.each(&:stop)
    end

    private

    def state_dir
      @base_env.fetch("SESSION_COCKPIT_STATE_DIR")
    end

    def put_into_inbox(content)
      inbox = File.join(state_dir, id, "inbox")
      FileUtils.mkdir_p(inbox)
      path = File.join(inbox, "#{Time.now.utc.strftime("%Y%m%dT%H%M%S.%6NZ")}-#{SecureRandom.uuid}.json")
      File.write(path, content)
      wait_until { !File.exist?(path) } if @mcp
    end

    def wait_until
      deadline = Time.now + TIMEOUT
      until yield
        raise "condition not met within #{TIMEOUT}s" if Time.now > deadline

        sleep 0.02
      end
    end

    # A fresh Claude Code process, which a process of its own stands in for,
    # and the plugin's hook and MCP server started for the current session.
    # Returns what the hook tells Claude.
    def launch_claude_code(source:)
      @claude = ChildProcess.spawn({}, "sleep", "3600")
      @claude_pid = @claude.pid.to_s
      @env = @base_env.merge("CLAUDE_CODE_SESSION_ID" => id, "SESSION_COCKPIT_CLAUDE_PID" => @claude_pid)
      told = run_session_start_hook(source: source)
      @mcp = ChildProcess.spawn(@env, EXE, "mcp")
      request("initialize", protocolVersion: "2025-06-18", capabilities: {},
                            clientInfo: { name: "test", version: "0" })
      @mcp.write_line(JSON.generate(jsonrpc: "2.0", method: "notifications/initialized"))
      told
    end

    # Runs the SessionStart hook and returns what it tells Claude.
    def run_session_start_hook(source:)
      input = JSON.generate(session_id: id, source: source, cwd: @project)
      hook_env = @env.merge("CLAUDE_CODE_SESSION_ID" => id, "CLAUDE_PID" => @claude_pid)
      output, error, status = Open3.capture3(hook_env, EXE, "session-start", stdin_data: input)
      raise <<~MESSAGE unless status.success?
        session-cockpit session-start failed:
        #{output}#{error}
      MESSAGE

      output
    end

    def request(method, **params)
      id = (@next_request_id += 1)
      @mcp.write_line(JSON.generate(jsonrpc: "2.0", id: id, method: method, params: params))
      loop do
        message = JSON.parse(@mcp.read_line(timeout: TIMEOUT))
        next unless message["id"] == id
        raise "MCP error: #{message["error"]}" if message["error"]

        return message["result"]
      end
    end
  end

  # A child process with line-oriented access to its stdin and stdout.
  class ChildProcess
    def self.spawn(env, *command)
      stdin, stdout, thread = Open3.popen2(env, *command)
      new(stdin, stdout, thread)
    end

    def initialize(stdin, stdout, thread)
      @stdin = stdin
      @stdout = stdout
      @thread = thread
    end

    def pid = @thread.pid

    def write_line(line)
      @stdin.puts(line)
      @stdin.flush
    end

    def read_line(timeout:)
      raise "no output within #{timeout}s" unless @stdout.wait_readable(timeout)

      @stdout.gets or raise "process exited"
    end

    def read_until_quiet(timeout:, quiet_period:)
      output = +""
      return output unless @stdout.wait_readable(timeout)

      output << @stdout.readpartial(4096) while @stdout.wait_readable(quiet_period)
      output.force_encoding(Encoding::UTF_8)
    rescue EOFError
      output.force_encoding(Encoding::UTF_8)
    end

    def stop
      Process.kill("TERM", @thread.pid)
      @thread.join
    rescue Errno::ESRCH
      nil
    end
  end
end
