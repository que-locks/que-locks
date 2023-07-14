module Que::Locks
  module ActiveJobExtensions
    class ExclusiveJobWrapper < ::ActiveJob::QueueAdapters::QueAdapter::JobWrapper
      # Opt into the locking functionality provided by que-locks
      self.exclusive_execution_lock = true
    end

    def enqueue(job)
      return super unless job.class.exclusive_execution_lock
      do_enqueue job
    end

    def enqueue_at(job, timestamp)
      return super unless job.class.exclusive_execution_lock
      do_enqueue job, run_at: Time.at(timestamp)
    end

    def do_enqueue(job, **job_options)
      job_options[:priority] = job.priority if job.respond_to? :priority

      # Forward the queue name as long as the job supports it, unless it's Rails 4
      # where queue names were used for priorities (see
      # https://github.com/rails/rails/pull/19498)
      if job.respond_to?(:queue_name) && ::ActiveJob.version.segments.first > 4
        job_options[:queue] = job.queue_name
      else
        job_options[:queue] = "default"
      end

      que_job = if require_job_options_kwarg?
          ExclusiveJobWrapper.enqueue job.serialize, job_options: job_options
        else
          ExclusiveJobWrapper.enqueue job.serialize, **job_options
        end

      if que_job && job.respond_to?(:provider_job_id=)
        job.provider_job_id = que_job.attrs["job_id"]
      end
      que_job
    end

    private

    def require_job_options_kwarg?
      @require_job_options_kwarg ||=
        self.method(:enqueue).parameters.any? { |ptype, pname| ptype == :key && pname == :job_options }
    end
  end
end
