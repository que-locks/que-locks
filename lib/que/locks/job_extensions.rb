module Que::Locks
  module JobExtensions
    attr_accessor :exclusive_execution_lock

    def lock_available?(*args, queue: nil, priority: nil, run_at: nil, job_class: nil, tags: nil, job_options: {}, **kwargs) # rubocop:disable Lint/UnusedMethodArgument
      args << kwargs if kwargs.any?
      return true unless self.exclusive_execution_lock
      return false if Que::Locks::ExecutionLock.already_enqueued_job_wanting_lock?(self, args)
      return Que::Locks::ExecutionLock.can_acquire?(self, args)
    end

    def enqueue(*args, queue: nil, priority: nil, run_at: nil, job_class: nil, tags: nil, job_options: {}, **kwargs)
      forwardable_kwargs = kwargs.clone
      forwardable_kwargs[:job_options] = {
        queue: queue,
        priority: priority,
        run_at: run_at,
        job_class: job_class,
        tags: tags,
      }.merge(job_options)

      if self.exclusive_execution_lock
        args_list = args.clone
        args_list << kwargs if kwargs.any?

        if Que::Locks::ExecutionLock.already_enqueued_job_wanting_lock?(self, args_list)
          Que.log(level: :info, event: :skipped_enqueue_due_to_preemptive_lock_check, args: args_list)
          # This technically breaks API compatibility with que, which always
          # returns a job. It could be argued that we should return the
          # already-enqueued job, but then we'd lose the ability to signal to
          # the caller that a job wasn't actually enqueued. Let's see how
          # far we can get with this.
          return
        end
      end

      super(*args, **forwardable_kwargs)
    end
  end
end

Que::Job.singleton_class.send(:prepend, Que::Locks::JobExtensions)
