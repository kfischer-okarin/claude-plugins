# frozen_string_literal: true

module SessionCockpit
  # What Claude Code's /rewind took back from Claude, as a log event.
  module Rewind
    # The rewound event for what of LOGGED, the session's events, TRANSCRIPT
    # no longer contains and no earlier rewound event names yet, or nil if
    # nothing is new: Claude's tool calls, and submissions as the monitor
    # delivered them in PROJECT.
    def self.taken_back(logged, transcript, project:)
      earlier = logged.select { it["type"] == "rewound" }
      calls = logged.filter_map { it["tool_use_id"] } - earlier.flat_map { it.fetch("tool_use_ids", []) }
      known_submissions = earlier.flat_map { it.fetch("submissions", []) }
      deliveries = logged.each_with_index.filter_map do |event, index|
        next unless event["type"] == "submitted" && !known_submissions.include?(event["id"])

        [event["id"], Formatter.submission(event, Agenda.from_events(logged[..index]), project: project)]
      end.to_h

      tool_use_ids = transcript.rewound_tool_calls(calls)
      submissions = deliveries.select { |_, text| transcript.rewound_deliveries([text]).any? }.keys
      return if tool_use_ids.empty? && submissions.empty?

      { "type" => "rewound", "tool_use_ids" => tool_use_ids, "submissions" => submissions }
    end
  end
end
