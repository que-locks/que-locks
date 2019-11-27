require_relative "test_helper"

$executions = []

class TestUntouchedJob < Que::Job
  def run(user_id)
    $executions << user_id
  end
end

class TestJob < Que::Job
  self.exclusive_execution_lock = true

  def run(user_id)
    $executions << user_id
  end
end

class TestReenqueueJob < Que::Job
  self.exclusive_execution_lock = true

  def run(user_id)
    $executions << user_id
    TestReenqueueJob.enqueue(user_id)
  end
end

class TestQueLocks < Minitest::Test
  def setup
    $executions = []
  end

  def test_sync_execution_of_untouched_job
    with_synchronous_execution do
      TestUntouchedJob.enqueue(1)
    end

    assert_equal [1], $executions
  end

  def test_sync_execution_of_locked_job
    with_synchronous_execution do
      TestJob.enqueue(1)
    end

    assert_equal [1], $executions
  end

  def test_execution_of_locked_job
    TestJob.enqueue(1)
    run_jobs
    assert_equal [1], $executions
  end

  def test_execution_of_locked_job_with_reenqueue_during_execution
    TestReenqueueJob.enqueue(1)
    run_jobs
    assert_equal [1], $executions
  end

  def test_multiple_execution_of_locked_job_with_reenqueue_during_execution
    TestReenqueueJob.enqueue(1)
    TestReenqueueJob.enqueue(2)
    TestReenqueueJob.enqueue(3)
    run_jobs
    assert_equal [1, 2, 3].sort, $executions.sort
  end
end
