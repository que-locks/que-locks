require "xxhash"

module Que
  SQL[:check_job_execution_lock] = %{
    SELECT COUNT(*) FROM public.que_jobs WHERE args = $1 and finished_at IS NULL AND expired_at IS NULL;
  }

  SQL[:try_aquire_execution_lock] = %{
    SELECT pg_try_advisory_lock(42, $1) AS locked
  }

  SQL[:release_execution_lock] = %{
    SELECT pg_advisory_unlock(42, $1)
  }

  module Locks::ExecutionLock
    class << self
      def lock_available?(args)
        args_string = Que.serialize_json(args)
        values = Que.execute(:check_job_execution_lock, [args_string]).first
        values[:count] == 0
      end

      def lock_key(args)
        XXhash.xxh32(Que.serialize_json(args), 42) / 2
      end

      def aquire!(key)
        result = Que.execute(:try_aquire_execution_lock, [key]).first
        result[:locked]
      end

      def release!(key)
        Que.execute(:release_execution_lock, [key])
      end
    end
  end
end
