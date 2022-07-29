require_relative "test_helper"

$executions = []

class TestUntouchedJob < Que::Job
  def run(user_id, **kwargs)
    args = kwargs.empty? ? user_id : [user_id] << kwargs
    $executions << args
  end
end

class TestJob < Que::Job
  self.exclusive_execution_lock = true

  def run(user_id, **kwargs)
    args = kwargs.empty? ? user_id : [user_id] << kwargs
    $executions << args
  end
end

class TestReenqueueJob < Que::Job
  self.exclusive_execution_lock = true

  def run(user_id)
    $executions << user_id
    TestReenqueueJob.enqueue(user_id)
  end
end

class TestUntouchedActiveJob < ActiveJob::Base
  def perform(user_id, **kwargs)
    args = kwargs.empty? ? user_id : [user_id] << kwargs
    $executions << args
  end
end

class TestActiveJob < ActiveJob::Base
  self.exclusive_execution_lock = true

  def perform(user_id, **kwargs)
    args = kwargs.empty? ? user_id : [user_id] << kwargs
    $executions << args
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

  def test_multiple_enqueued_untouched_jobs
    TestUntouchedJob.enqueue(1)
    TestUntouchedJob.enqueue(1)
    run_jobs

    assert_equal [1, 1], $executions
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

  def test_multiple_enqueued_locked_jobs
    TestJob.enqueue(1)
    TestJob.enqueue(1)
    run_jobs

    assert_equal [1], $executions # one should be deduped
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

  def test_can_enqueue_untouched_job_with_deprecated_api_including_run_at
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).never

    run_at = Time.now
    job = nil
    _, stderr = capture_subprocess_io do
      job = TestUntouchedJob.enqueue(1, queue: :foo, priority: 10, run_at: run_at, job_class: :bar, tags: [:baz], unrelated: :qux)
    end

    assert_equal :foo, job.que_attrs[:queue].to_sym
    assert_equal 10, job.que_attrs[:priority]
    assert_equal run_at.to_i, job.que_attrs[:run_at].to_i
    assert_equal :bar, job.que_attrs[:job_class].to_sym
    assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

    # Refute any deprecation notice, since we rewrote the options
    refute_includes stderr, "Please wrap job options in an explicit"
  end

  def test_can_enqueue_untouched_job_with_deprecated_api
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).never

    with_synchronous_execution do
      job = nil
      _, stderr = capture_subprocess_io do
        job = TestUntouchedJob.enqueue(1, queue: :foo, priority: 10, job_class: :bar, tags: [:baz], unrelated: :qux)
      end
      assert_equal :foo, job.que_attrs[:queue].to_sym
      assert_equal 10, job.que_attrs[:priority]
      assert_equal :bar, job.que_attrs[:job_class].to_sym
      assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

      # Refute any deprecation notice, since we rewrote the options
      refute_includes stderr, "Please wrap job options in an explicit"
    end

    assert_equal [[1, { unrelated: "qux" }]], $executions
  end

  def test_can_enqueue_untouched_job_with_v2_api_including_run_at
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).never

    run_at = Time.now
    job = nil
    _, stderr = capture_subprocess_io do
      job = TestUntouchedJob.enqueue(1, unrelated: :qux, job_options: { queue: :foo, priority: 10, run_at: run_at, job_class: :bar, tags: [:baz] })
    end

    assert_equal :foo, job.que_attrs[:queue].to_sym
    assert_equal 10, job.que_attrs[:priority]
    assert_equal run_at.to_i, job.que_attrs[:run_at].to_i
    assert_equal :bar, job.que_attrs[:job_class].to_sym
    assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

    # Assert lack of deprecation notice
    refute_includes stderr, "Please wrap job options in an explicit"
  end

  def test_can_enqueue_untouched_job_with_v2_api
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).never

    with_synchronous_execution do
      job = nil
      _, stderr = capture_subprocess_io do
        job = TestUntouchedJob.enqueue(1, unrelated: :qux, job_options: { queue: :foo, priority: 10, job_class: :bar, tags: [:baz] })
      end

      assert_equal :foo, job.que_attrs[:queue].to_sym
      assert_equal 10, job.que_attrs[:priority]
      assert_equal :bar, job.que_attrs[:job_class].to_sym
      assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

      # Assert lack of deprecation notice
      refute_includes stderr, "Please wrap job options in an explicit"
    end

    assert_equal [[1, { unrelated: "qux" }]], $executions
  end

  def test_can_enqueue_locked_job_with_deprecated_api_including_run_at
    # Expect the common que options to not be included in the check
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).with(TestJob, [1, unrelated: :qux]).returns(false)

    run_at = Time.now
    job = nil
    _, stderr = capture_subprocess_io do
      job = TestJob.enqueue(1, queue: :foo, priority: 10, run_at: run_at, job_class: :bar, tags: [:baz], unrelated: :qux)
    end

    assert_equal :foo, job.que_attrs[:queue].to_sym
    assert_equal 10, job.que_attrs[:priority]
    assert_equal run_at.to_i, job.que_attrs[:run_at].to_i
    assert_equal :bar, job.que_attrs[:job_class].to_sym
    assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

    # Refute any deprecation notice, since we rewrote the options
    refute_includes stderr, "Please wrap job options in an explicit"
  end

  def test_can_enqueue_locked_job_with_deprecated_api
    # Expect the common que options to not be included in the check
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).with(TestJob, [1, unrelated: :qux]).returns(false)

    with_synchronous_execution do
      job = nil
      _, stderr = capture_subprocess_io do
        job = TestJob.enqueue(1, queue: :foo, priority: 10, job_class: :bar, tags: [:baz], unrelated: :qux)
      end
      assert_equal :foo, job.que_attrs[:queue].to_sym
      assert_equal 10, job.que_attrs[:priority]
      assert_equal :bar, job.que_attrs[:job_class].to_sym
      assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

      # Refute any deprecation notice, since we rewrote the options
      refute_includes stderr, "Please wrap job options in an explicit"
    end
    assert_equal [[1, { unrelated: "qux" }]], $executions
  end

  def test_can_enqueue_locked_job_with_v2_api_including_run_at
    # Expect the common que options to not be included in the check
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).with(TestJob, [1, unrelated: :qux]).returns(false)

    run_at = Time.now
    job = nil
    _, stderr = capture_subprocess_io do
      job = TestJob.enqueue(1, unrelated: :qux, job_options: { queue: :foo, priority: 10, run_at: run_at, job_class: :bar, tags: [:baz] })
    end

    assert_equal :foo, job.que_attrs[:queue].to_sym
    assert_equal 10, job.que_attrs[:priority]
    assert_equal run_at.to_i, job.que_attrs[:run_at].to_i
    assert_equal :bar, job.que_attrs[:job_class].to_sym
    assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

    # Assert lack of deprecation notice
    refute_includes stderr, "Please wrap job options in an explicit"
  end

  def test_can_enqueue_locked_job_with_v2_api
    # Expect the common que options to not be included in the check
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).with(TestJob, [1, unrelated: :qux]).returns(false)

    with_synchronous_execution do
      job = nil
      _, stderr = capture_subprocess_io do
        job = TestJob.enqueue(1, unrelated: :qux, job_options: { queue: :foo, priority: 10, job_class: :bar, tags: [:baz] })
      end
      assert_equal :foo, job.que_attrs[:queue].to_sym
      assert_equal 10, job.que_attrs[:priority]
      assert_equal :bar, job.que_attrs[:job_class].to_sym
      assert_equal({ tags: ["baz"] }, job.que_attrs[:data])

      # Assert lack of deprecation notice
      refute_includes stderr, "Please wrap job options in an explicit"
    end
    assert_equal [[1, { unrelated: "qux" }]], $executions
  end

  def test_job_options_overrides_kwarg
    job = TestJob.enqueue(1, queue: :foo, job_options: { queue: :bar })
    assert_equal :bar, job.que_attrs[:queue].to_sym
  end

  def test_can_enqueue_untouched_active_job
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).never

    with_synchronous_execution do
      TestUntouchedActiveJob.perform_later 1, unrelated: :qux
    end
    assert_equal [[1, { unrelated: :qux }]], $executions
  end

  def test_multiple_enqueued_untouched_active_jobs
    TestUntouchedActiveJob.perform_later 1
    TestUntouchedActiveJob.perform_later 1
    run_jobs

    assert_equal [1, 1], $executions
  end

  def test_can_enqueue_locked_active_job
    assert_args = lambda do |klass, args|
      assert_equal Que::Locks::ActiveJobExtensions::ExclusiveJobWrapper, klass
      assert_equal 1, args.length
      assert_equal "TestActiveJob", args.first["job_class"]
      assert_equal [1, { "unrelated" => { "_aj_serialized" => "ActiveJob::Serializers::SymbolSerializer", "value" => "qux" }, "_aj_symbol_keys" => ["unrelated"] }], args.first["arguments"]
    end

    mock_lock = mock("lock")
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).with(&assert_args).returns(false)
    Que::Locks::ExecutionLock.expects(:lock_key).with(&assert_args).returns(mock_lock)
    Que::Locks::ExecutionLock.expects(:acquire!).with(mock_lock).returns(true)
    Que::Locks::ExecutionLock.expects(:release!).with(mock_lock)

    TestActiveJob.perform_later 1, unrelated: :qux
    run_jobs
    assert_equal [[1, { unrelated: :qux }]], $executions
  end

  def test_can_enqueue_locked_active_job_skipped_if_lock_taken
    assert_args = lambda do |klass, args|
      assert_equal Que::Locks::ActiveJobExtensions::ExclusiveJobWrapper, klass
      assert_equal 1, args.length
      assert_equal "TestActiveJob", args.first["job_class"]
      assert_equal [1], args.first["arguments"]
    end

    mock_lock = mock("lock")
    Que::Locks::ExecutionLock.expects(:already_enqueued_job_wanting_lock?).with(&assert_args).returns(false)
    Que::Locks::ExecutionLock.expects(:lock_key).with(&assert_args).returns(mock_lock)
    Que::Locks::ExecutionLock.expects(:acquire!).with(mock_lock).returns(false)

    TestActiveJob.perform_later 1
    run_jobs
    assert_empty $executions
  end

  def test_multiple_enqueued_locked_active_jobs
    TestActiveJob.perform_later 1
    TestActiveJob.perform_later 1
    run_jobs

    assert_equal [1], $executions # one should be deduped
  end

  def test_multiple_unique_enqueued_locked_active_jobs
    TestActiveJob.perform_later 1
    TestActiveJob.perform_later 2
    run_jobs

    assert_equal [1, 2], $executions
  end

  def test_multiple_unique_enqueued_locked_active_jobs_with_kwargs
    TestActiveJob.perform_later 1
    TestActiveJob.perform_later 1, unrelated: :qux
    run_jobs

    assert_equal [1, [1, { unrelated: :qux }]], $executions
  end
end
