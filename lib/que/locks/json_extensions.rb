require "neatjson"

module Que::Locks::JSONExtensions
  def serialize_json(object)
    JSON.neat_generate(object, sort: true)
  end
end

Que.singleton_class.send(:prepend, Que::Locks::JSONExtensions)
