require "neatjson"

# For comparing job args, the JSON serialization of them is used
# This patches Que to use a stable json serialization that is independent of the insertion order of keys into hash arguments
module Que::Locks::JSONExtensions
  def serialize_json(object)
    JSON.neat_generate(object, sort: true)
  end
end

Que.singleton_class.send(:prepend, Que::Locks::JSONExtensions)
