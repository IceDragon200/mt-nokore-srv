local M = assert(nokore_node_data.NodeDataService)
local case = foundation.com.Luna:new("nokore_node_data.NodeDataService")
local path_join = assert(foundation.com.path_join)

local world_path = path_join(core.get_worldpath(), "/tmp")
case:describe("#initialize/1", function (t2)
  t2:test("can initialize a new node_data service", function (t3)
    local m = M:new({
      world_path = world_path,
    })

    t3:assert(m)
  end)
end)

case:describe("#update/2", function (t2)
  t2:test("can update an empty service", function (t3)
    local m = M:new({
      world_path = world_path,
    })
    m:update(1.0)
  end)

  t2:test("can update with nodes", function (t3)
    local m = M:new({
      world_path = world_path,
      expires_duration = 1.0,
    })
    t3:assert_feq(m.expires_duration, 1.0)
    local node_data = m:unsafe_request_node_data(vector.new(0, 0, 0), "my_secret")
    t3:assert(m:get_node_data(node_data.pos))
    t3:assert_feq(1.0, node_data.expires_at)
    local item = m.next_expire_node:peek()
    t3:assert(item)
    t3:assert_eq(node_data.id, item.id)
    t3:assert_eq(node_data.expires_at, item.expires_at)
    m:update(2.0)
    t3:assert(node_data.expired)
    t3:refute(m:get_node_data(node_data.pos))
  end)
end)

case:describe("#request_node_data/2", function (t2)
  t2:test("can retrieve new node_data", function (t3)
    local m = M:new({
      world_path = world_path,
    })
    local pos = vector.new(0, 0, 0)
    local okay, node_data = m:request_node_data(pos, "my_secret")
    t3:assert_eq(true, okay)
    t3:assert(node_data)

    -- Cannot request it again with a different secret
    okay, node_data = m:request_node_data(pos, "my_secret2")
    t3:assert_eq(false, okay)
    t3:refute(node_data)

    okay = m:destroy_node_data(pos)
    t3:assert_eq(true, okay)
  end)
end)

case:execute()
case:display_stats()
case:maybe_error()
