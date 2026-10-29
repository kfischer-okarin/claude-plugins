# frozen_string_literal: true

require "cgi"

module SessionCockpit
  # A session's transcript as Claude Code writes it, read for what /rewind
  # took back. Its entries form a tree through parentUuid: a rewind leaves
  # the old entries in place and goes on from an earlier one, so the
  # conversation as it stands is the chain from the newest entry back.
  # Compaction cuts that chain at a boundary, whose logicalParentUuid may name
  # an entry no longer in the file; entries before the chain's earliest one
  # are taken as compacted rather than rewound.
  class Transcript
    def self.read(path)
      new(File.foreach(path).filter_map do |line|
        next unless line.include?('"uuid"')

        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end)
    end

    # The session a fork of another one, such as through /branch, was copied
    # from, or nil.
    def self.forked_from(path)
      File.foreach(path) do |line|
        next unless line.include?('"forkedFrom"')

        session_id = JSON.parse(line).dig("forkedFrom", "sessionId")
        return session_id if session_id
      rescue JSON::ParserError
        next
      end
      nil
    end

    def initialize(entries)
      @entries = entries
      @index = entries.each_with_index.to_h { |entry, index| [entry["uuid"], index] }
      @branch = branch
      @branch_start = @branch.map { @index[it] }.compact.min || entries.length
      @messages_on_branch = entries.select { @branch.include?(it["uuid"]) && it["type"] == "assistant" }
                                   .map { it.dig("message", "id") }.compact.to_set
    end

    # Of TOOL_USE_IDS, those of tool calls the conversation no longer
    # contains. A call not written yet is still contained.
    def rewound_tool_calls(tool_use_ids)
      tool_use_ids.select do |id|
        entry = @entries.find { |e| e["type"] == "assistant" && tool_use_ids_of(e).include?(id) }
        entry && !kept?(entry)
      end
    end

    # Of TEXTS, each as the monitor printed it, those of deliveries the
    # conversation no longer contains: found, but only where rewound. Claude
    # Code passes monitor output on without indentation and empty lines.
    def rewound_deliveries(texts)
      texts.select do |text|
        delivered = without_indentation(text)
        found = @entries.select do
          it["type"] == "user" && without_indentation(CGI.unescapeHTML(content_of(it))).include?(delivered)
        end
        found.any? && found.none? { kept?(it) }
      end
    end

    private

    # The UUIDs of the entries from the newest one back to the start, or to
    # the last compaction.
    def branch
      newest = @entries.reverse.find { %w[user assistant].include?(it["type"]) && !it["isSidechain"] }
      chain = Set.new
      uuid = newest&.dig("uuid")
      while uuid && !chain.include?(uuid)
        chain << uuid
        entry = @index[uuid] && @entries[@index[uuid]]
        uuid = entry && (entry["parentUuid"] || entry["logicalParentUuid"])
      end
      chain
    end

    # Whether ENTRY is part of the conversation as it stands. Tool calls made
    # together are written as entries side by side, of which the chain runs
    # through only one: the others are kept by sharing its message, and their
    # results by following them.
    def kept?(entry)
      return true if @branch.include?(entry["uuid"]) || @index[entry["uuid"]] < @branch_start
      return true if entry["type"] == "assistant" && @messages_on_branch.include?(entry.dig("message", "id"))

      parent = @index[entry["parentUuid"]] && @entries[@index[entry["parentUuid"]]]
      tool_result?(entry) && parent && kept?(parent)
    end

    def tool_result?(entry)
      Array(entry.dig("message", "content")).any? { it.is_a?(Hash) && it["type"] == "tool_result" }
    end

    def tool_use_ids_of(entry)
      Array(entry.dig("message", "content")).filter_map { it["id"] if it.is_a?(Hash) && it["type"] == "tool_use" }
    end

    def without_indentation(text) = text.lines.map(&:strip).reject(&:empty?).join("\n")

    def content_of(entry)
      content = entry.dig("message", "content")
      return content if content.is_a?(String)

      Array(content).filter_map { it["text"] if it.is_a?(Hash) }.join("\n")
    end
  end
end
