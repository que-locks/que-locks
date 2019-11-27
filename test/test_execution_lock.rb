require_relative "test_helper"

class TestExecutionLock < Minitest::Test
  def test_test_setup_connection_pool
    get_id, id_result = Queue.new, Queue.new
    t =
      Thread.new do
        Que.pool.checkout do |conn|
          get_id.pop
          id_result.push(conn.backend_pid)
        end
      end

    Que.pool.checkout do |conn|
      outer_backend_pid = conn.backend_pid
      get_id.push(nil)
      inner_backend_pid = id_result.pop
      refute_equal outer_backend_pid, inner_backend_pid
      t.join
    end
  end

  def test_lock_can_be_reaquired_by_same_connection
    Que.pool.checkout do
      assert Que::Locks::ExecutionLock.aquire!(123)
      assert Que::Locks::ExecutionLock.aquire!(123)
      assert Que::Locks::ExecutionLock.release!(123)
      assert Que::Locks::ExecutionLock.release!(123)
    end
  end

  def test_aquiring_lock
    try_aquire, done_trying = Queue.new, Queue.new
    t =
      Thread.new do
        Que.pool.checkout do |_conn|
          try_aquire.pop
          refute Que::Locks::ExecutionLock.can_aquire_key?(123)
          refute Que::Locks::ExecutionLock.aquire!(123)
          done_trying.push(nil)

          try_aquire.pop
          # Test the lock can be aquired again after releasing
          assert Que::Locks::ExecutionLock.aquire!(123)
          assert Que::Locks::ExecutionLock.release!(123)
          assert Que::Locks::ExecutionLock.can_aquire_key?(123)
          done_trying.push(nil)
        end
      end

    Que.pool.checkout do |_conn|
      # Acquire the lock in this outer thread
      assert Que::Locks::ExecutionLock.can_aquire_key?(123)
      assert Que::Locks::ExecutionLock.aquire!(123)

      # Ensure the inner thread can't acquire it
      try_aquire.push(nil)
      done_trying.pop

      # Release the lock in this outer thread so we can assert the inner thread can later acquire it
      assert Que::Locks::ExecutionLock.release!(123)
      assert Que::Locks::ExecutionLock.can_aquire_key?(123)
      try_aquire.push(nil)

      # Assert it can be acquired in the inner thread
      done_trying.pop
      t.join
    end
  end

  def test_release_unaquired_lock
    assert Que::Locks::ExecutionLock.release!(123)
  end

  def test_checking_lock_after_aquisition_doesnt_release
    try_aquire, done_trying = Queue.new, Queue.new
    t =
      Thread.new do
        Que.pool.checkout do |_conn|
          try_aquire.pop
          refute Que::Locks::ExecutionLock.can_aquire_key?(123)
          try_aquire.pop
          refute Que::Locks::ExecutionLock.can_aquire_key?(123)
          done_trying.push(nil)
        end
      end

    Que.pool.checkout do |_conn|
      # Acquire the lock in this outer thread, then tell the inner thread to check if it can be acquired.
      assert Que::Locks::ExecutionLock.aquire!(123)
      try_aquire.push(nil)

      # Then check if it can be acquired on the outer thread, which would unlock if there was a bug with the check function
      Que::Locks::ExecutionLock.can_aquire_key?(123)
      try_aquire.push(nil)

      done_trying.pop
      t.join
      assert Que::Locks::ExecutionLock.release!(123)
    end
  end
end
