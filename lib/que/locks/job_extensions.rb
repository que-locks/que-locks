module Que::Locks
  module JobExtensions
    attr_accessor :exclusive_execution_lock

    def lock_available?(*args, queue: nil, priority: nil, run_at: nil, job_class: nil, tags: nil, job_options: {}, **kwargs) # rubocop:disable Lint/UnusedMethodArgument
      args << kwargs if kwargs.any?
      return true unless self.exclusive_execution_lock
      return false if Que::Locks::ExecutionLock.already_enqueued_job_wanting_lock?(self, args)
      return Que::Locks::ExecutionLock.can_aquire?(self, args)
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
        else
          super(*args, **forwardable_kwargs)
        end
      else
        super(*args, **forwardable_kwargs)
      end
    end
  end
end

Que::Job.singleton_class.send(:prepend, Que::Locks::JobExtensions)
