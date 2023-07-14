require "minitest/autorun"
require "mocha/minitest"
require "rails/railtie"
require "active_record"
require "active_job" # this must come before que for its monkeypatch
require "que"
require "que/locks"
require "byebug"
require "database_cleaner"

# Run railtie initializers so we get our activejob extensions
Que::Locks::Railtie.initializers.each(&:run)

# use docker-compose'd postgres by default
ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URL", "postgres://que_locks@localhost/que_locks_test"))

Que.connection = ActiveRecord
Que::Migrations.migrate!(version: Que::Migrations::CURRENT_VERSION)

logger = Logger.new(STDOUT, level: Logger::WARN)
Que.logger = logger
Que.internal_logger = logger
ActiveJob::Base.logger = logger
ActiveJob::Base.queue_adapter = :que
DatabaseCleaner.strategy = :truncation

class Minitest::Test
  def teardown
    # Reset connection pool which releases all locks
    Que.connection = ActiveRecord
    DatabaseCleaner.clean
  end

  def with_synchronous_execution
    old = Que.run_synchronously
    Que.run_synchronously = true
    yield
  ensure
    Que.run_synchronously = old
  end

  def sleep_until(*args, &block)
    sleep_until?(*args, &block) || raise("sleep_until timeout reached")
  end

  ruby2_keywords(:sleep_until) if respond_to?(:ruby2_keywords, true)

  def sleep_until?(timeout: SLEEP_UNTIL_TIMEOUT)
    deadline = Time.now + timeout
    loop do
      if (result = yield)
        return result
      end

      if Time.now > deadline
        return false
      end

      sleep 0.01
    end
  end

  def run_jobs
    job_buffer = Que::JobBuffer.new(maximum_size: 20, priorities: [10, 30, 50, nil])
    result_queue = Que::ResultQueue.new

    jobs = ActiveRecord::Base.connection.execute("SELECT * FROM que_jobs;").to_a.map do |job|
      job.symbolize_keys!
      job[:args] = JSON.parse(job[:args])
      job[:kwargs] = JSON.parse(job[:kwargs]) if job[:kwargs]
      job
    end

    result_queue.clear
    jobs.map! { |job| Que::Metajob.new(job) }
    job_ids = jobs.map(&:id).sort
    job_buffer.push(*jobs)
    Que::Worker.new(job_buffer: job_buffer, result_queue: result_queue)

    sleep_until timeout: 10 do
      finished_job_ids(result_queue) == job_ids
    end
  end

  def finished_job_ids(result_queue)
    result_queue.to_a.select { |m| m[:message_type] == :job_finished }.map { |m| m.fetch(:metajob).id }.sort
  end
end
