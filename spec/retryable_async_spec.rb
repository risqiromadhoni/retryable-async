require 'retryable/async'

RSpec.describe Retryable::Async do
  it 'retries until success' do
    counter = 0
    Retryable::Async.run(max_attempts: 3) do
      counter += 1
      raise 'fail' if counter < 3
    end
    expect(counter).to eq(3)
  end
end
