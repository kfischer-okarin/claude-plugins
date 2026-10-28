# frozen_string_literal: true

module SessionCockpit
  # One session's state: the event log the MCP server alone writes, the
  # agenda materialized from it, the inbox Emacs submits into, how far the
  # monitor has delivered, and what Emacs's session picker lists it with.
  class SessionState
    LOG_MUTEX = Mutex.new

    def initialize(path)
      @path = path
    end

    # Records PROJECT, the directory Claude Code runs the session in, for
    # Emacs's session picker and for the files questions point at.
    def record_project(project)
      FileUtils.mkdir_p(@path)
      AtomicFile.write(file("session.json"), JSON.generate(project: project))
    end

    # The directory Claude Code runs the session in.
    def project
      JSON.parse(File.read(file("session.json")))["project"]
    end

    def id = File.basename(@path)

    # Turns the cockpit on for the session. Only then does it take questions,
    # so none get asked in a session nobody answers them in.
    def turn_cockpit_on
      FileUtils.mkdir_p(@path)
      FileUtils.touch(file("cockpit"))
    end

    def cockpit_on? = File.exist?(file("cockpit"))

    # Appends the event the block builds from the agenda as it is now, and
    # returns it.
    def append(&build_event)
      append_all { [build_event.(it)] }.first
    end

    # Appends the events the block builds from the agenda as it is now, all
    # or none, and returns them. Tool calls and the inbox take turns, so they
    # neither hand out the same ID nor leave an outdated agenda behind.
    def append_all
      FileUtils.mkdir_p(@path)
      LOG_MUTEX.synchronize do
        File.open(file("events.jsonl"), "a+") do |log|
          log.rewind
          agenda = Agenda.from_events(log.each_line.map { JSON.parse(it) })
          events = yield(agenda)
          log.write(events.map { "#{JSON.generate(it)}\n" }.join)
          log.flush
          AtomicFile.write(file("agenda.json"), JSON.generate(events.reduce(agenda, :apply).to_h))
          events
        end
      end
    end

    # Takes the user's submissions out of the inbox into the log, oldest
    # first. A file that does not parse yet is still being written, so it
    # and everything after it wait for the next round.
    def integrate_inbox
      Dir.glob(File.join(file("inbox"), "*.json")).sort.each do |path|
        event = JSON.parse(File.read(path))
        append { event }
        File.delete(path)
      rescue JSON::ParserError
        break
      end
    end

    # Prints the submissions Claude has not seen yet to OUT. How far the log
    # has been delivered is kept next to it, so a monitor started again after
    # --resume picks up where the last one stopped.
    def deliver_new_submissions(out)
      return unless File.exist?(file("events.jsonl"))

      offset = File.exist?(file("delivered")) ? File.read(file("delivered")).to_i : 0
      new_lines = complete_lines_after(offset)
      return if new_lines.empty?

      new_lines.map { JSON.parse(it) }.select { it["type"] == "submitted" }
               .each { out.print Formatter.submission(it, agenda, project: project) }
      AtomicFile.write(file("delivered"), (offset + new_lines.sum(&:bytesize)).to_s)
    end

    def agenda
      events = File.exist?(file("events.jsonl")) ? complete_lines_after(0).map { JSON.parse(it) } : []
      Agenda.from_events(events)
    end

    private

    # The log's lines after OFFSET, leaving out a last line still being
    # written.
    def complete_lines_after(offset)
      File.open(file("events.jsonl")) do |log|
        log.seek(offset)
        log.read.lines.select { it.end_with?("\n") }
      end
    end

    def file(name)
      File.join(@path, name)
    end
  end
end
