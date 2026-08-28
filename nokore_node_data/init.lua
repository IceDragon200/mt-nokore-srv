---
--- When all else fails, NoKore Node Data provides a KVStore on a per-node basis, nodes must
--- request a KVStore before they can use it however.
---
--- @namespace nokore_node_data
local mod = foundation.new_module("nokore_node_data", "1.0.0")

mod:require("service.lua")
mod:require("api.lua")
if foundation.com.Luna then
  mod:require("tests.lua")
end
