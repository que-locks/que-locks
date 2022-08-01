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
      job_options[:queue] = job.queue_name if job.respond_to? :queue_name

      que_job = ExclusiveJobWrapper.enqueue job.serialize, job_options: job_options
      if que_job && job.respond_to?(:provider_job_id=)
        job.provider_job_id = que_job.attrs["job_id"]
      end
      que_job
    end
  end
end
