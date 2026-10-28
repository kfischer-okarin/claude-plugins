module SessionCockpit
  module Watch
    def self.run(out:)
      loop do
        deliver(out)
        sleep 0.1
      end
    end
  end
end
