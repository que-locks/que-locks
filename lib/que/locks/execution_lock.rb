require "xxhash"

module Que
  SQL[:args_already_enqueued] = %{
    SELECT COUNT(*) FROM public.que_jobs WHERE job_class = $1 AND args = $2 AND finished_at IS NULL AND expired_at IS NULL LIMIT 1;
  }

  SQL[:active_job_args_already_enqueued] = %{
    SELECT COUNT(*) FROM public.que_jobs WHERE job_class = $1 AND args->0 @> $2 AND finished_at IS NULL AND expired_at IS NULL LIMIT 1;
  }

  SQL[:try_acquire_execution_lock] = %{
    SELECT pg_try_advisory_lock(42, $1) AS locked
  }

  SQL[:release_execution_lock] = %{
    SELECT pg_advisory_unlock(42, $1)
  }

  module Locks::ExecutionLock
    class << self
      def already_enqueued_job_wanting_lock?(klass, args)
        query = :args_already_enqueued
        if active_job_class?(klass)
          args = active_jobless_args(args)
          query = :active_job_args_already_enqueued
        end

        args_string = Que.serialize_json(args)
        values = Que.execute(query, [klass.name, args_string]).first
        values[:count] != 0
      end

      def can_acquire?(klass, args)
        can_acquire_key?(lock_key(klass, args))
      end

      def can_acquire_key?(key)
        result = false
        begin
          result = acquire!(key)
        ensure
          if result
            release!(key)
          end
        end
        result
      end

      def lock_key(klass, args)
        if active_job_class?(klass)
          args = active_jobless_args(args)
        end
        XXhash.xxh32(klass.name + ":" + Que.serialize_json(args), 42) / 2
      end

      def acquire!(key)
        result = Que.execute(:try_acquire_execution_lock, [key]).first
        result[:locked]
      end

      def release!(key)
        Que.execute(:release_execution_lock, [key])
      end

      private

      def active_job_class?(klass)
        if Object.const_defined?("ActiveJob::QueueAdapters::QueAdapter::JobWrapper")
          return klass.ancestors.include? ::ActiveJob::QueueAdapters::QueAdapter::JobWrapper
        end
        false
      end

      def active_jobless_args(args)
        # ActiveJob handles its own arguments, and thus comes in as one argument:
        # a single serialized hash representing the job. We want to use this hash
        # to check and see if we already have an equivalent job queued up, but that
        # requires us to toss out irrelevant ActiveJob-specific parameters that will
        # throw our check off. There are enough of these
        # (see ActiveJob::Core#serialize) that it's easier to maintain a whitelist;
        # toss everything else.
        hash = args.first
        okay_keys = ["job_class", "arguments"]
        # Careful, this is a shallow copy, don't actually modify that hash
        hash.reject { |key| !okay_keys.include?(key) }
      end
    end
  end
end
