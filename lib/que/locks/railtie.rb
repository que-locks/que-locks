module Que::Locks
  class Railtie < Rails::Railtie
    initializer "que-locks.patch_active_job" do
      ActiveSupport.on_load(:active_job) do
        class_attribute :exclusive_execution_lock

        require_relative "active_job_extensions"
        ActiveJob::QueueAdapters::QueAdapter.prepend(Que::Locks::ActiveJobExtensions)
        ActiveJob::QueueAdapters::QueAdapter.singleton_class.prepend(Que::Locks::ActiveJobExtensions) # for rails 4
      end
    end
  end
end
