module Que::Locks
  LockMiddleware = ->(job, &block) {
    if job.class.exclusive_execution_lock
      args = job.que_attrs[:args]
      lock_key = ExecutionLock.lock_key(job.class, args)
      if ExecutionLock.aquire!(lock_key)
        begin
          block.call
        ensure
          ExecutionLock.release!(lock_key)
        end
      else
        Que.log(level: :info, event: :skipped_execution_due_to_lock, args: args, job_class: job.class.name)
      end
    else
      block.call
    end

    nil
  }
end

Que.job_middleware.push(Que::Locks::LockMiddleware)
