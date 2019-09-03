source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem 'que', '1.0.0.beta3', github: 'chanks/que'

# Specify your gem's dependencies in que-locks.gemspec
gemspec

group :development do
  gem 'activerecord'
  gem 'pg'

  gem 'minitest'

  gem 'byebug'
  gem 'rufo'
  gem 'rubocop'
  gem 'rubocop-performance'
end

