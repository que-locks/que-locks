source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "que", "1.0.0.beta3", github: "que-rb/que", ref: "53106609b24d7e8bc231ae3883f69dca8c989d9d"

# Specify your gem's dependencies in que-locks.gemspec
gemspec

group :development do
  gem "activerecord"
  gem "activejob"
  gem "pg"
  gem "database_cleaner"

  gem "minitest"

  gem "byebug"
  gem "rufo"
  gem "rubocop"
  gem "rubocop-performance"
end
