local mod = assert(nokore_node_data)
local RingBuffer = assert(foundation.com.RingBuffer)
local hash_node_position = assert(core.hash_node_position)
local KVStore = assert(nokore.KVStore)
local path_join = assert(foundation.com.path_join)
local Trace = foundation.com.Trace

--- @namespace nokore_node_data

--- @class NodeDataService
mod.NodeDataService = foundation.com.Class:extends("nokore_node_data.NodeDataService")
do
  local ic = mod.NodeDataService.instance_class

  --- @override
  --- @spec #initialize(options: Table): void
  function ic:initialize(options)
    options = options or {}
    ic._super.initialize(self)

    --- @member monotonic_time: Float
    self.monotonic_time = 0
    --- @member elapsed_since_last_update: Float
    self.elapsed_since_last_update = 0
    --- @member expires_duration: Float
    self.expires_duration = options.expires_duration or 120 -- every 2 minutes
    --- @member persist_interval: Float
    self.persist_interval = options.persist_interval or 60 -- every minute
    --- @member nodes: Record<ID, NodeData>
    self.nodes = {}
    --- @member expired_nodes: Record<ID, Boolean>
    self.expired_nodes = {}
    --- @member next_expire_node: RingBuffer
    self.next_expire_node = RingBuffer:new()
    --- @member next_persist_node: RingBuffer
    self.next_persist_node = RingBuffer:new()
    --- @member nokore_dir: String
    self.nokore_dir = path_join(options.world_path or core.get_worldpath(), "nokore")
    --- @member node_data_dir: String
    self.node_data_dir = path_join(self.nokore_dir, "node_data")

    if type(options.persistence_type) == "string" then
      core.log("info", "options specified specific persistence_type " .. options.persistence_type)
      self.persistence_type = options.persistence_type
    else
      core.log("debug", "determining best persistence automatically")
      if KVStore.instance_class.marshall_dump then
        self.persistence_type = "MRSH"
      elseif KVStore.instance_class.apack_dump then
        self.persistence_type = "ASCI"
      else
        self.persistence_type = "NONE"
      end
    end

    if self.persistence_type == "MRSH" then
      core.log("info", "node data will be persisted using marshall")
    elseif self.persistence_type == "ASCI" then
      core.log("info", "node data will be persisted using ascii_pack")
    elseif self.persistence_type == "NONE" then
      core.log(
        "warning",
        "node data cannot be persisted, neither ascii pack nor marshall_dump is available"
      )
    else
      error("unexpected persistence type (got " .. dump(self.persistence_type) .. ")")
    end
  end

  --- @spec #terminate(): void
  function ic:terminate()
    local trace
    local span
    if Trace then
      trace = Trace:new('nokore_node_data/terminate')
    end
    for node_id, node in pairs(self.nodes) do
      if trace then
        span = trace:span_start('nodes/'..node_id)
      end
      self:persist_node(node, span)
      if span then
        span:span_end()
      end
    end
    if trace then
      trace:span_end()
    end
    self.nodes = {}
  end

  --- @spec #update(dtime: Number, trace: Trace): void
  function ic:update(dtime, trace)
    self.monotonic_time = self.monotonic_time + dtime
    self.elapsed_since_last_update = self.elapsed_since_last_update + dtime

    if self.elapsed_since_last_update < 1 then
      return
    end
    self.elapsed_since_last_update = 0

    local item
    local node

    while not self.next_expire_node:is_empty() do
      item = self.next_expire_node:peek()
      if item.expires_at <= self.monotonic_time then
        self.next_expire_node:pop()
        node = self.nodes[item.id]

        if node then
          if node.expires_at <= self.monotonic_time then
            self.expired_nodes[item.id] = true
          else
            self.next_expire_node:push({
              id = item.id,
              expires_at = node.expires_at,
            })
          end
        end
      else
        break
      end
    end

    while not self.next_persist_node:is_empty() do
      item = self.next_persist_node:peek()
      if item.next_persist_at <= self.monotonic_time then
        self.next_persist_node:pop()
        node = self.nodes[item.id]
        if node then
          if node.next_persist_at <= self.monotonic_time then
            self:persist_node(node)
          end
        end
      else
        break
      end
    end

    if next(self.expired_nodes) then
      local span
      for id,_ in pairs(self.expired_nodes) do
        if trace then
          span = trace:span_start("expired_node:" .. id)
        end
        node = self.nodes[id]
        node.expired = true
        self.nodes[id] = nil
        self:persist_node(node, span)
        if span then
          span:span_end()
        end
      end
      self.expired_nodes = {}
    end
  end

  --- @spec #refresh_node_data_expiration(node_data: NodeData): void
  function ic:refresh_node_data_expiration(node_data)
    node_data.expires_at = self.monotonic_time + self.expires_duration
    self.next_expire_node:push({
      id = assert(node_data.id),
      expires_at = node_data.expires_at,
    })
  end

  function ic:init_node_data_timers(node_data)
    self:refresh_node_data_expiration(node_data)
    self.next_persist_node:push({
      id = node_data.id,
      next_persist_at = node_data.next_persist_at,
    })
  end

  --- Triggers expiration renewal on the node data, nodes should ocassionally
  --- issue a ping to keep this data alive.
  ---
  --- @spec ping_node_data(pos: Vector3): Boolean
  function ic:ping_node_data(pos)
    local id = hash_node_position(pos)
    local node_data = self.nodes[id]
    if node_data then
      self:refresh_node_data_expiration(node_data)
      return true
    end
    return false
  end

  --- @spec #new_node_data(pos: Vector3, secret: String): NodeData
  function ic:new_node_data(pos, secret)
    local basename = "("..pos.x..","..pos.y..","..pos.z..")"
    local kv = KVStore:new()
    local id = hash_node_position(pos)
    kv:put("__secret", secret)
    if self.persistence_type == "MRSH" then
      filename = self.node_data_dir .. "/" .. basename .. ".mrsh"
    elseif self.persistence_type == "ASCI" then
      filename = self.node_data_dir .. "/" .. basename .. ".asci"
    end

    local node_data = {
      expired = false,
      id = id,
      pos = vector.new(pos),
      basename = basename,
      filename = filename,
      secret = secret,
      kv = kv,
      persisted_at = self.monotonic_time,
      next_persist_at = self.monotonic_time + self.persist_interval,
      expires_at = self.monotonic_time + self.expires_duration,
    }

    return node_data
  end

  --- Requests an existing or new NodeData item.
  --- Secret can be provided to ensure the NodeData returned belonged to a specific node.
  --- Note, nodes that want to know IF NodeData exists should use get_node_data instead.
  --- This functions WILL destroy NodeData that doesn't match the secret, so be very careful with
  --- it.
  --- @spec #unsafe_request_node_data(pos: Vector3, secret: String): NodeData
  function ic:unsafe_request_node_data(pos, secret)
    local id = hash_node_position(pos)
    local node_data = self.nodes[id]
    if node_data then
      if node_data.secret == secret then
        return node_data
      else
        node_data = self:new_node_data(pos, secret)
        self.nodes[id] = node_data
        self:init_node_data_timers(node_data)
        return node_data
      end
    else
      node_data = self:new_node_data(pos, secret)
      self:load_node_data(node_data)
      if node_data.kv:get("__secret") ~= secret then
        node_data = self:new_node_data(pos, secret)
      end
      self.nodes[id] = node_data
      self:init_node_data_timers(node_data)
      return node_data
    end
  end

  --- Safe variant of unsafe_request_node_data/2, this will return a tuple of:
  --- (Boolean, NodeData | nil).
  --- If true is returned, then the data was successfully loaded or created.
  --- If false, then the secret likely doesn't match the original.
  --- @spec #request_node_data(pos: Vector3, secret: String): (true, NodeData) | (false, nil)
  function ic:request_node_data(pos, secret)
    local id = hash_node_position(pos)
    local node_data = self.nodes[id]
    if node_data then
      if node_data.secret == secret then
        return true, node_data
      else
        return false, nil
      end
    else
      node_data = self:new_node_data(pos, secret)
      self:load_node_data(node_data)
      if node_data.kv:get("__secret") ~= secret then
        return false, nil
      end
      self.nodes[id] = node_data
      self:init_node_data_timers(node_data)
      return true, node_data
    end
  end

  --- Removes and deletes node_data at specified position, with optional secret.
  --- @spec #destroy_node_data(pos: Vector3, secret?: String): Boolean
  function ic:destroy_node_data(pos, secret)
    local id = hash_node_position(pos)
    local node_data = self.nodes[id]
    if node_data then
      if secret then
        if node_data.secret ~= secret then
          return false
        end
      end

      if node_data.filename then
        os.remove(node_data.filename)
      end
      self.nodes[id] = nil
      return true
    end
    return false
  end

  --- Attempt to load any data associated with the node_data from disk
  --- @spec #load_node_data(node_data: NodeData): void
  function ic:load_node_data(node_data)
    if self.persistence_type == "MRSH" then
      node_data.kv:marshall_load_file(node_data.filename)
    elseif self.persistence_type == "ASCI" then
      node_data.kv:apack_load_file(node_data.filename)
    end
  end

  --- @spec #persist_node(NodeData, Trace): void
  function ic:persist_node(node, trace)
    local kv = node.kv
    -- in case someone deleted the node dir during runtime, this covers it up
    -- hopefully the engine is doing this efficiently.
    if kv.dirty then
      core.mkdir(self.node_data_dir)
      kv.dirty = false
      if self.persistence_type == "MRSH" then
        kv:marshall_dump_file(node.filename, trace)
      elseif self.persistence_type == "ASCI" then
        kv:apack_dump_file(node.filename, trace)
      end
    end
    node.persisted_at = self.monotonic_time
    node.next_persist_at = node.persisted_at + self.persist_interval
    self.next_persist_node:push({
      id = node.id,
      next_persist_at = node.next_persist_at,
    })
  end

  --- @spec #get_node_data(pos: Vector3): NodeData
  function ic:get_node_data(pos)
    local id = hash_node_position(pos)
    return self.nodes[id]
  end
end
