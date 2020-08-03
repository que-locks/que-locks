# Que::Locks ![Ruby](https://github.com/airhorns/que-locks/workflows/Ruby/badge.svg)

`que-locks` adds an opt-in exclusive execution lock to [Que](https://github.com/que-rb/que), a robust and simple Postgres based background job library. Jobs can specify that exactly one instance of a job should be executing at once and `que-locks` will prevent the enqueuing and execution of any other instance of the same job with the same arguments. This is useful for jobs that are doing something important that should only ever happen one at a time, like processing a payment for a given user, or super expensive jobs that could cause thundering herd problems if enqueued all at the same time.

`que-locks` uses Postgres' advisory locks in a similar manner as que does to provide scalable and automatically cleaned-up-locking around job execution. `que-locks` provides slightly better atomicity guarantees compared to the locking functionality of Redis based job queues for the same reasons `que` can as well! Because locks are taken and released using the same database connection that the `que` worker uses to pull jobs, the robust transactional semantics Postgres provides apply just the same. Locks are automatically released if the connection fails, and don't require heart-beating beyond what the Postgres client already does, unlike the multi-step Redis logic that requires lock TTLs, heartbeats, and complicated crash cleanup.

This is also sometimes called _unique jobs_, _serialized jobs_, _job concurrency limiting_, and/or _exclusive jobs_.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'que-locks'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install que-locks
```

**Note**: `que-locks` is built for Que 1.0, which is at this time not the default version of que you'll get if you don't specify a prerelease que version like `1.0.0.beta3` in your application's Gemfile.

## Usage

After requiring the gem, set the `exclusive_execution_lock` property on your job class:

```ruby
class SomeJob < Que::Job
  self.exclusive_execution_lock = true

  def run(user_id:, bar:)
    # useful stuff
  end
end
```

That's it!

## Configuration (Important!)

Right now, `que-locks` does __not__ support Que running with a `--worker-count` greater than 1! This is because the locking strategy is not compatible with the way Que uses it's connection pool. This is a big limitation we hope to remove, but please note that you must run Que with one worker per process when using `que-locks`. 

### Checking lock status

Occasionally, code enqueuing a job might want to check if the job is already running and do something different if it is, like display a message to the user or log the skipped execution. `que-locks` supports some basic job lock introspection like so:

```ruby
SomeJob.exclusive_execution_lock  #=> returns true if the job is indeed using que-locks

SomeJob.lock_available?(user_id: 1)  #=> returns true if no job is currently enqueued with these arguments or running right now holding the lock
```

**Note**: Checking the lock's availability reports on the current state of the locks, but that state might change in between when the check is made and if/when the job is enqueued with the same arguments. Put differently, the `#lock_available?` method is advisory to user code, and doesn't actually reserve the lock or execute a compare-and-swap operation. It's safe for multiple processes to race to enqueue a job after checking to see that the lock is available, as only one will still be executed, but they may both report that the lock was available before enqueuing.

## Semantics

`que-locks` guarantees that the maximum number of instances of a given job class executing with a given set of arguments will be one. This means that:

- two of the same job class each pushed with the same arguments may result in one or two executions, but they won't ever be simultaneous
- two of the same job class each pushed with different arguments can both execute simultaneously
- if the job takes no arguments, there can only ever be one executing globally

In some instances, multiple jobs with the same class and arguments can be enqueued and sit in the queue simultaneously. Despite this, the semantics above will remain in tact: only one job will execute at once. The first one dequeued will get the lock, and the second one dequeued will skip execution if the first job is still executing when it checks. If 100 of the same job class are enqueued all at the same time with the same arguments, only one will run simultaneously, but that more than one might run by the time the queue is empty.

`que-locks` uses a sorted JSON serialized version of the arguments to compute lock keys, so it's important that arguments that should be considered identical JSON serialize using `Que.serialize_json` to the exact same string.

`que-locks` adds no overhead to jobs that don't use locking, adds one more SQL query to check an advisory lock (which is only memory access) to enqueuing jobs, and adds two more SQL queries to lock and unlock to job execution.

### Preemptive lock checking (dropped enqueues)

`que-locks` tries to avoid extraneous job pushes by checking to see if the lock for a job is available at enqueue time, and skipping enqueue for the job if so. This means that if you enqueue 100 jobs all at once, likely very few will end up executing total because the first job executed will take out the lock and the preemptive enqueue check for the jobs yet to be enqueued will start failing. This preemptive lock check helps keeps queues small in the event that a huge number of identical jobs are pushed at once. It is worth noting that this job dropping behaviour happens already at dequeue time as well if the lock is already out, and this is just doing the check earlier in the process to enqueue fewer jobs.

In some instances this may be undesirable if the job must absolutely run. In this instance, we suggest not using an execution lock, but, you may still want control over how many are running at once. One alternative is pushing some kind of idempotency token or further identifier as one of the job's arguments to change the lock key such that the dropped jobs are ok to drop.

Otherwise, we suggest throttling the concurrency of a given `que` queue name by controlling the number of que workers working it, and enqueuing the jobs that must not run simultaneously to that queue name.

```ruby
class ProcessCreditCardJob < Que::Job
  self.queue = 'remote_api_jobs'
end

# and then run que against that queue with a limited worker count to take it easy on the remote API
# que --queue-name remote_api_jobs --worker-count 2
```

See https://github.com/que-rb/que/tree/master/docs#multiple-queues for more information on setting concurrency for multiple queue names.

It can be tricky to puzzle out if you have a job locking or a job concurrency limiting problem. A good rule of thumb to identify a locking problem is to ask if the jobs are idempotent or redundant if simultaneously executed. If they are, and it is indeed ok to drop jobs from existence if they happen to run at the same time as a clone is running, it's a locking problem that optimizes from doing redundant work. If all jobs must be run, even if they take the exact same arguments, but they maybe just need to be serialized such that only one runs at once, a concurrency limiting approach applies better.

## Missing features

- Configurable preemptive lock checking at enqueue time
- Selective argument comparison for lock key computation
- maybe a `que-web` integration to expose lock info
- ActiveJob integration for Rails users. It'd be nice for those who prefer the ActiveJob::Job API to use `que-locks` for nice transactional locking semantics, but this doesn't exist yet. In the meantime, we suggest using `Que::Job` directly.

If you wish for any of this stuff, feel free to open a PR, contributions are always welcome!!

## Non features

- Locking to a limited concurrency greater than 1. Also called semaphore tickets. If you want a lock that several different jobs can take out, a good option is to use Que's multiple queue support and run a limited number of workers working a certain queue so the concurrency is limited by the available worker slots. This is absent because it adds a lot of complexity to the locking code as Postgres doesn't natively support these cross-session, stacking advisory locks.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/airhorns/que-locks. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Que::Locks project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hornairs/que-locks/blob/master/CODE_OF_CONDUCT.md).
