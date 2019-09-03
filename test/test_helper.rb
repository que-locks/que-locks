require "minitest/autorun"
require "que"
require "que/locks"
require "byebug"
require "active_record"

ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URL", "postgres://localhost/que-test"))
Que.connection = ActiveRecord
Que::Migrations.migrate!(version: Que::Migrations::CURRENT_VERSION)

Que.logger = Logger.new(STDOUT)
Que.internal_logger = Logger.new(STDOUT)
