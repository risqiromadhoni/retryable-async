# frozen_string_literal: true

module Retryable
  module Async
    DEFAULT_OPTIONS = {
      max_attempts: 3,
      on: [StandardError],
      base_delay: 1.0,
      backoff: :linear, # or :exponential
      jitter: false,
      before_retry: nil
    }

    def self.run(**opts)
      options = DEFAULT_OPTIONS.merge(opts)
      attempt = 0

      begin
        attempt += 1
        yield
      rescue *options[:on] => e
        raise e unless attempt < options[:max_attempts]

        options[:before_retry]&.call(attempt, e)
        delay = calculate_delay(attempt, options)
        async_sleep(delay)
        retry
      end
    end

    def self.calculate_delay(attempt, options)
      delay =
        case options[:backoff]
        when :exponential
          options[:base_delay] * (2**(attempt - 1))
        else
          options[:base_delay] * attempt
        end
      options[:jitter] ? delay * (0.5 + rand) : delay
    end

    def self.async_sleep(seconds)
      if defined?(Async::Task) && Async::Task.current?
        Async::Task.current.sleep(seconds)
      else
        sleep(seconds)
      end
    end
  end
end
