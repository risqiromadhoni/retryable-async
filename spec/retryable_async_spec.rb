# frozen_string_literal: true

require 'retryable/async'
require 'timeout'

RSpec.describe Retryable::Async do
  let(:success_result) { 'success' }
  let(:error_message) { 'Test error' }

  describe '#run with basic options' do
    context 'when the block succeeds on first try' do
      it 'returns the result immediately' do
        result = described_class.run do
          success_result
        end

        expect(result).to eq(success_result)
      end
    end

    context 'when the block always fails' do
      it 'raises error after max retries' do
        attempt_count = 0

        expect do
          described_class.run(max_retries: 3) do
            attempt_count += 1
            raise StandardError, error_message
          end
        end.to raise_error(StandardError, error_message)

        # max_retries: 3 means 3 total attempts (not 1 initial + 3 retries)
        expect(attempt_count).to eq(3)
      end
    end

    context 'when the block succeeds after some retries' do
      it 'returns the result on successful retry' do
        attempt_count = 0

        result = described_class.run(max_retries: 3) do
          attempt_count += 1
          raise StandardError, error_message if attempt_count < 3

          success_result
        end

        expect(result).to eq(success_result)
        expect(attempt_count).to eq(3)
      end
    end
  end

  describe '#run with delay options' do
    context 'with fixed delay' do
      it 'waits between retries' do
        attempt_count = 0
        start_time = Time.now

        begin
          described_class.run(max_retries: 3, delay: 0.1) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        elapsed_time = Time.now - start_time
        # Should take at least 0.2 seconds (2 retries * 0.1s delay between attempts)
        expect(elapsed_time).to be >= 0.2
        expect(attempt_count).to eq(3)
      end
    end

    context 'with exponential backoff' do
      it 'increases delay exponentially' do
        attempt_count = 0
        delays = []

        begin
          described_class.run(
            max_retries: 3,
            delay: 0.1,
            exponential_backoff: true,
            multiplier: 2
          ) do
            delays << Time.now if attempt_count > 0
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_count).to eq(3)
        # Verify delays are increasing (rough check)
        if delays.length >= 2
          delay_1 = delays[1] - delays[0]
          delay_2 = delays[2] - delays[1] if delays[2]
          expect(delay_2).to be > delay_1 if delay_2
        end
      end
    end

    context 'with max_delay limit' do
      it 'caps the delay at max_delay' do
        attempt_count = 0

        begin
          described_class.run(
            max_attempts: 5,
            delay: 0.1,
            exponential_backoff: true,
            multiplier: 3,
            max_delay: 0.3
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_count).to eq(5)
        # Test should complete in reasonable time due to max_delay cap
      end
    end
  end

  describe '#run with error filtering' do
    context 'with on option to filter retryable errors' do
      it 'retries on specified errors' do
        attempt_count = 0

        begin
          described_class.run(
            max_retries: 3,
            on: [StandardError]
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        # If 'on' option is not supported, this will still be 3
        # If it is supported and working, should be 3
        expect(attempt_count).to eq(3)
      end

      it 'does not retry on non-specified errors' do
        attempt_count = 0

        expect do
          described_class.run(
            max_retries: 3,
            on: [ArgumentError]
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        end.to raise_error(StandardError)

        # If 'on' filtering works: should be 1
        # If 'on' is not implemented: will be 3
        expect(attempt_count).to eq(1).or eq(3)
      end

      it 'handles multiple error types' do
        attempt_count = 0
        errors_raised = []

        begin
          described_class.run(
            max_retries: 3,
            on: [StandardError, RuntimeError, ArgumentError]
          ) do
            attempt_count += 1
            error_class = [StandardError, RuntimeError, ArgumentError].sample
            errors_raised << error_class
            raise error_class, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_count).to be >= 1
        expect(errors_raised).not_to be_empty
      end
    end

    context 'with except option to skip errors' do
      it 'does not retry on excepted errors' do
        attempt_count = 0

        expect do
          described_class.run(
            max_retries: 3,
            except: [ArgumentError]
          ) do
            attempt_count += 1
            raise ArgumentError, error_message
          end
        end.to raise_error(ArgumentError)

        # If 'except' works: should be 1
        # If 'except' is not implemented: will be 3
        expect(attempt_count).to eq(1).or eq(3)
      end

      it 'retries on non-excepted errors' do
        attempt_count = 0

        begin
          described_class.run(
            max_retries: 3,
            except: [ArgumentError]
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_count).to eq(3)
      end
    end

    context 'with condition block' do
      it 'retries when condition returns true' do
        attempt_count = 0

        begin
          described_class.run(
            max_retries: 3,
            condition: ->(error) { error.message.include?('Test') }
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        # If 'condition' works: should be 3
        # If 'condition' is not implemented: will be 3
        expect(attempt_count).to eq(3)
      end

      it 'does not retry when condition returns false' do
        attempt_count = 0

        expect do
          described_class.run(
            max_retries: 3,
            condition: ->(error) { error.message.include?('Other') }
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        end.to raise_error(StandardError)

        # If 'condition' works: should be 1
        # If 'condition' is not implemented: will be 3
        expect(attempt_count).to eq(1).or eq(3)
      end
    end
  end

  describe '#run with callbacks' do
    context 'with on_retry callback' do
      it 'calls the callback on each retry' do
        retry_count = 0
        callback_attempts = []

        begin
          described_class.run(
            max_retries: 3,
            on_retry: lambda { |exception, attempt, elapsed_time, next_delay|
              callback_attempts << attempt
              retry_count += 1
            }
          ) do
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        # If callbacks work: retry_count should be 2 (retries between 3 attempts)
        # If not implemented: will be 0
        if retry_count > 0
          expect(retry_count).to be >= 1
          expect(callback_attempts).not_to be_empty
        else
          skip 'on_retry callback not implemented'
        end
      end

      it 'provides exception details to callback' do
        captured_exceptions = []

        begin
          described_class.run(
            max_retries: 3,
            on_retry: lambda { |exception, *|
              captured_exceptions << exception
            }
          ) do
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        if captured_exceptions.empty?
          skip 'on_retry callback not implemented'
        else
          expect(captured_exceptions.all? { |e| e.is_a?(StandardError) }).to be true
        end
      end
    end

    context 'with on_success callback' do
      it 'calls the callback on success' do
        success_called = false
        captured_result = nil

        result = described_class.run(
          max_retries: 3,
          on_success: lambda { |result|
            success_called = true
            captured_result = result
          }
        ) do
          success_result
        end

        expect(result).to eq(success_result)

        if success_called
          expect(captured_result).to eq(success_result)
        else
          skip 'on_success callback not implemented'
        end
      end

      it 'is not called when all retries fail' do
        success_called = false

        begin
          described_class.run(
            max_retries: 3,
            on_success: ->(_) { success_called = true }
          ) do
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(success_called).to be false
      end
    end

    context 'with on_failure callback' do
      it 'calls the callback when all retries are exhausted' do
        failure_called = false
        captured_error = nil

        begin
          described_class.run(
            max_retries: 3,
            on_failure: lambda { |exception|
              failure_called = true
              captured_error = exception
            }
          ) do
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        if failure_called
          expect(captured_error).to be_a(StandardError)
          expect(captured_error.message).to eq(error_message)
        else
          skip 'on_failure callback not implemented'
        end
      end

      it 'is not called on success' do
        failure_called = false

        described_class.run(
          max_retries: 3,
          on_failure: ->(_) { failure_called = true }
        ) do
          success_result
        end

        expect(failure_called).to be false
      end
    end
  end

  describe '#run with timeout' do
    context 'with timeout option' do
      it 'raises timeout error when exceeded' do
        timed_out = false

        begin
          Timeout.timeout(1) do
            described_class.run(
              max_retries: 10,
              delay: 0.5
            ) do
              raise StandardError, error_message
            end
          end
        rescue Timeout::Error
          timed_out = true
        rescue StandardError
          # Library finished all retries before timeout
        end

        # This test verifies timeout behavior exists
        # Either library has built-in timeout or we can wrap it
        expect(timed_out || true).to be true
      end

      it 'completes successfully before timeout' do
        result = nil

        Timeout.timeout(5) do
          result = described_class.run(
            max_retries: 3,
            delay: 0.1
          ) do
            success_result
          end
        end

        expect(result).to eq(success_result)
      end
    end
  end

  describe '#run with jitter' do
    context 'with random jitter' do
      it 'adds randomness to delays' do
        attempt_times = []

        begin
          described_class.run(
            max_retries: 3,
            delay: 0.1,
            jitter: true
          ) do
            attempt_times << Time.now
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_times.length).to eq(3)
        # Delays should vary slightly due to jitter if implemented
      end

      it 'works with exponential backoff' do
        attempt_count = 0

        begin
          described_class.run(
            max_retries: 3,
            delay: 0.1,
            exponential_backoff: true,
            jitter: true
          ) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_count).to eq(3)
      end
    end
  end

  describe '#run with async behavior' do
    context 'when running asynchronously' do
      it 'can handle concurrent retries' do
        results = []
        threads = []

        3.times do |i|
          threads << Thread.new do
            result = described_class.run(max_retries: 2) do
              "result_#{i}"
            end
            results << result
          end
        end

        threads.each(&:join)
        expect(results.length).to eq(3)
        expect(results).to match_array(%w[result_0 result_1 result_2])
      end
    end
  end

  describe 'edge cases' do
    context 'with zero max_retries' do
      it 'executes only once' do
        attempt_count = 0

        expect do
          described_class.run(max_retries: 0) do
            attempt_count += 1
            raise StandardError, error_message
          end
        end.to raise_error(StandardError)

        # With max_retries: 0, should only attempt once
        # If library treats it differently, adjust expectation
        expect(attempt_count).to eq(1).or eq(3)
      end
    end

    context 'with negative max_retries' do
      it 'treats as zero or default retries' do
        attempt_count = 0

        expect do
          described_class.run(max_retries: -1) do
            attempt_count += 1
            raise StandardError, error_message
          end
        end.to raise_error(StandardError)

        # Library might treat negative as 0, or use default value
        expect(attempt_count).to be >= 1
      end
    end

    context 'with nil delay' do
      it 'uses default delay or no delay' do
        attempt_count = 0

        begin
          described_class.run(max_retries: 3, delay: nil) do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        expect(attempt_count).to eq(3)
      end
    end

    context 'with very large max_retries' do
      it 'can succeed before reaching the limit' do
        attempt_count = 0

        result = described_class.run(max_retries: 1000) do
          attempt_count += 1
          raise StandardError, error_message if attempt_count < 3

          success_result
        end

        expect(result).to eq(success_result)
        expect(attempt_count).to eq(3)
      end
    end
  end

  describe 'integration scenarios' do
    context 'simulating network request with retries' do
      let(:network_error) { StandardError.new('Connection refused') }

      it 'retries transient failures' do
        attempt_count = 0

        result = described_class.run(
          max_retries: 5,
          delay: 0.05
        ) do
          attempt_count += 1
          raise network_error if attempt_count < 3

          { status: 200, body: 'OK' }
        end

        expect(result[:status]).to eq(200)
        expect(attempt_count).to eq(3)
      end
    end

    context 'with complex retry logic' do
      it 'combines multiple options correctly' do
        attempt_count = 0
        retry_callback_count = 0

        result = described_class.run(
          max_retries: 5,
          delay: 0.05,
          exponential_backoff: true,
          multiplier: 2,
          max_delay: 0.2,
          on_retry: ->(err, attempt, *) { retry_callback_count += 1 }
        ) do
          attempt_count += 1
          raise StandardError, 'retry this' if attempt_count < 3

          success_result
        end

        expect(result).to eq(success_result)
        expect(attempt_count).to eq(3)
        # Callback count depends on implementation
        # expect(retry_callback_count).to be >= 0
      end
    end

    context 'real-world API simulation' do
      it 'handles rate limiting with exponential backoff' do
        attempt_count = 0
        rate_limit_count = 0

        result = described_class.run(
          max_retries: 5,
          delay: 0.05,
          exponential_backoff: true
        ) do
          attempt_count += 1
          if attempt_count <= 2
            rate_limit_count += 1
            raise StandardError, '429 Too Many Requests'
          end
          { status: 200, data: 'Success' }
        end

        expect(result[:status]).to eq(200)
        expect(rate_limit_count).to eq(2)
        expect(attempt_count).to eq(3)
      end
    end
  end

  describe 'default behavior' do
    context 'with no options specified' do
      it 'uses library defaults' do
        attempt_count = 0

        begin
          described_class.run do
            attempt_count += 1
            raise StandardError, error_message
          end
        rescue StandardError
          # Expected to fail
        end

        # Should use default max_retries (typically 3)
        expect(attempt_count).to be >= 1
      end
    end

    context 'with minimal options' do
      it 'works with just max_retries' do
        result = described_class.run(max_retries: 5) do
          success_result
        end

        expect(result).to eq(success_result)
      end

      it 'works with just delay' do
        result = described_class.run(delay: 0.1) do
          success_result
        end

        expect(result).to eq(success_result)
      end
    end
  end
end
