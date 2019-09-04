require_relative "test_helper"

$executions = []

class TestUntouchedJob < Que::Job
  def run(user_id:)
    $executions << user_id
  end
end

class TestJob < Que::Job
  self.exclusive_execution_lock = true

  def run(user_id:)
    $executions << user_id
  end
end

class TestQueLocks < Minitest::Test
  def setup
    $executions = []
  end

  def test_execution_of_untouched_job
    with_synchronous_execution do
      TestUntouchedJob.enqueue(user_id: 1)
    end

    assert_equal [1], $executions
  end

  def test_sync_execution_of_locked_job
    with_synchronous_execution do
      TestJob.enqueue(user_id: 1)
    end

    assert_equal [1], $executions
  end

  def test_can_aquire_lock
    assert Que::Locks::ExecutionLock.can_aquire?(123)
  end

  def with_synchronous_execution
    old = Que.run_synchronously
    Que.run_synchronously = true
    yield
  ensure
    Que.run_synchronously = old
  end
end
