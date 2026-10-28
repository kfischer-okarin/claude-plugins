# frozen_string_literal: true

module SessionCockpit
  # Files that readers must never see half-written.
  module AtomicFile
    # Writes through a temporary file renamed into place.
    def self.write(path, content)
      temp_path = "#{path}.#{Process.pid}.tmp"
      File.write(temp_path, content)
      File.rename(temp_path, path)
    end
  end
end
