module Que::Locks
  module JobExtensions
    attr_accessor :exclusive_execution_lock

    def enqueue(*args, queue: nil, priority: nil, run_at: nil, job_class: nil, tags: nil, **arg_opts)
      if self.exclusive_execution_lock
        args_list = args.clone
        args_list << arg_opts if arg_opts.any?

        if Que::Locks::ExecutionLock.lock_available?(args_list)
          super
        else
          Que.log(level: :info, event: :skipped_enqueue_due_to_lock, args: args_list)
        end
      else
        super
      end
    end
  end
end

Que::Job.singleton_class.send(:prepend, Que::Locks::JobExtensions)
