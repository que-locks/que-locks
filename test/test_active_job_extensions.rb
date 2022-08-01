require_relative "test_helper"

class TestUntouchedActiveJob < ActiveJob::Base
end

class TestUntouchedActiveJobWithPriority < ActiveJob::Base
  queue_with_priority 1
end

class TestUntouchedActiveJobWithQueueName < ActiveJob::Base
  queue_as :not_default
end

class TestActiveJob < ActiveJob::Base
  self.exclusive_execution_lock = true
end

class TestActiveJobWithPriority < ActiveJob::Base
  self.exclusive_execution_lock = true
  queue_with_priority 1
end

class TestActiveJobWithQueueName < ActiveJob::Base
  self.exclusive_execution_lock = true
  queue_as :not_default
end

class TestActiveJobExtensions < Minitest::Test
  def test_can_enqueue_untouched_active_job
    TestUntouchedActiveJob.perform_later 1

    assert_equal "default", job.que_attrs["queue"]
    assert_equal 100, job.que_attrs["priority"]
  end

  def test_can_enqueue_untouched_active_job_with_priority
    TestUntouchedActiveJobWithPriority.perform_later 1

    assert_equal "default", job.que_attrs["queue"]
    assert_equal 1, job.que_attrs["priority"]
  end

  def test_can_enqueue_untouched_active_job_with_queue_name
    TestUntouchedActiveJobWithQueueName.perform_later 1

    assert_equal "not_default", job.que_attrs["queue"]
    assert_equal 100, job.que_attrs["priority"]
  end

  def test_can_enqueue_locked_active_job
    TestActiveJob.perform_later 1

    assert_equal "default", job.que_attrs["queue"]
    assert_equal 100, job.que_attrs["priority"]
  end

  def test_can_enqueue_locked_active_job_with_priority
    TestActiveJobWithPriority.perform_later 1

    assert_equal "default", job.que_attrs["queue"]
    assert_equal 1, job.que_attrs["priority"]
  end

  def test_can_enqueue_locked_active_job_with_queue_name
    TestActiveJobWithQueueName.perform_later 1

    assert_equal "not_default", job.que_attrs["queue"]
    assert_equal 100, job.que_attrs["priority"]
  end

  def test_can_enqueue_locked_active_job_with_queue_name_on_rails4
    ActiveJob.expects(:version).returns(Gem::Version.new("4.2.11.1"))

    TestActiveJobWithQueueName.perform_later 1

    assert_equal "default", job.que_attrs["queue"] # Don't forward queue name on rails 4
    assert_equal 100, job.que_attrs["priority"]
  end

  private

  def job
    jobs = ActiveRecord::Base.connection.execute("SELECT * FROM que_jobs;").to_a.map { |j| Que::Job.new(j) }
    assert_equal 1, jobs.length
    jobs.first
  end
end
