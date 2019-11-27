# Que::Locks

`que-locks` adds an opt-in feature to `Que::Jobs` allowing jobs to specify that exactly one instance of a job should be executing at once. This is useful for jobs that are doing something important that should only ever happen one at a time, like processing a payment for a given user, or super expensive jobs that could cause thundering herd problems if enqueued all at the same time.

`que-locks` uses Postgres' advisory locks in a similar manner as que `0.x` did to provide scalable and automatically cleaned up locking around job execution. `que-locks` provides slightly better atomicity guarantees compared to the locking functionality of Redis based job queues for the same reasons `que` can as well. Because locks are taken and released using the same database connection that the `que` worker uses to pull jobs, the transactional semantics apply just the same where locks are automatically released if the connection fails, unlike the multistep Redis logic that requires complicated crash cleanup.

This is also sometimes called "unique jobs", "job concurrency limiting", and "exclusive jobs".

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'que-locks'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install que-locks

## Usage

After requiring the gem, set the `exclusive_execution_lock` property on your job class:

```ruby
class SomeJob < Que::Job
  self.exclusive_execution_lock = true

  def run(foo:, bar:)
    # useful stuff
  end
end
```

That's it!

## Semantics

`que-locks` guarantees that the maximum number of instances given job class executing with a given set of arguments will be one. This means that:

- two of the same job class each pushed with different arguments can both execute simultaneously
- if the job takes no arguments, there can only ever be one executing globally
- two of the same job class each pushed with the same arguments may result in one or two executions, but they won't ever be simultaneous

In some instances, multiple jobs with the same arguments can be enqueued and sit in the queue simultaneously. Despite this the semantics above will remain in tact: only one job will execute at once. The first one worked will get the lock and the second one worked will skip execution if the first job is still executing. `que-locks` tries to avoid extraneous job pushes by checking to see if the lock for a job is available at enqueue time, and skipping enqueue if so. This preemptive lock check helps keeps queues small in the event that a huge number of identical jobs are pushed at once.

`que-locks` uses a sorted JSON serialized version of the arguments to compute lock keys, so it's important that arguments that should be considered identical JSON serialize using `Que.serialize_json` to the exact same string.

`que-locks` adds no overhead to jobs that don't use locking, adds one more SQL query to check an advisory lock (which is only memory access) to enqueuing jobs, and adds two more SQL queries to lock and unlock to job execution.

## Missing features

- Configurable preemptive lock checking at enqueue time
- Selective argument comparison for lock key computation
- maybe a `que-web` integration to expose lock info

If you wish for any of this stuff, feel free to open a PR, contributions are always welcome!!

## Non features

- Locking to a limited concurrency greater than 1. If you want a lock that several different jobs can take out, a good option is to use Que's multiple queue support and run a limited number of workers working a certain queue so the concurrency is limited by the available worker slots.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hornairs/que-locks. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Que::Locks project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hornairs/que-locks/blob/master/CODE_OF_CONDUCT.md).
