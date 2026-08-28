--- @namespace nokore_block_data
local RingBuffer = assert(foundation.com.RingBuffer)
local floor = assert(math.floor)
local KVStore = assert(nokore.KVStore)
local Trace = foundation.com.Trace
local path_join = assert(foundation.com.path_join)
local hash_node_position = assert(core.hash_node_position)
local get_connected_players = assert(core.get_connected_players)
local get_active_blocks = core.get_active_blocks
local ACTIVE_BLOCK_RANGE = tonumber(core.settings:get("active_block_range")) or 4

local function hash_position(x, y, z)
  return (z + 0x8000) * 0x100000000 + (y + 0x8000) * 0x10000 + (x + 0x8000)
end

nokore_block_data.hash_position = hash_position

--- @class BlockDataService
local BlockDataService = foundation.com.Class:extends("nokore_block_data.BlockDataService")
do
  local ic = BlockDataService.instance_class

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
    self.expires_duration = 120 -- every 2 minutes
    --- @member persist_interval: Float
    self.persist_interval = 60 -- every minute
    --- @member blocks: Record<ID, Block>
    self.blocks = {}
    --- @member expired_blocks: Record<ID, Boolean>
    self.expired_blocks = {}
    --- @member next_expire_block: RingBuffer
    self.next_expire_block = RingBuffer:new()
    --- @member next_persist_block: RingBuffer
    self.next_persist_block = RingBuffer:new()
    --- @member player_block_pos_cache: Record<String, Any>
    self.player_block_pos_cache = {}
    --- @member range: Integer
    self.range = ACTIVE_BLOCK_RANGE
    --- @member nokore_dir: String
    self.nokore_dir = path_join(options.world_path or core.get_worldpath(), "nokore")
    --- @member block_data_dir: String
    self.block_data_dir = path_join(self.nokore_dir, "block_data")
    --- @member registered_on_block_available: Record<String, Function/2>
    self.registered_on_block_available = nokore_common.new_callbacks()
    --- @member registered_on_block_expired: Record<String, Function/2>
    self.registered_on_block_expired = nokore_common.new_callbacks()

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
      core.log("info", "block data will be persisted using marshall")
    elseif self.persistence_type == "ASCI" then
      core.log("info", "block data will be persisted using ascii_pack")
    elseif self.persistence_type == "NONE" then
      core.log(
        "warning",
        "block data cannot be persisted, neither ascii pack nor marshall_dump is available"
      )
    else
      error("unexpected persistence type (got " .. dump(self.persistence_type) .. ")")
    end

    if get_active_blocks then
      core.log("info", "will use get_active_blocks to determine loaded blocks")
    else
      core.log("info", "will use cube around player to determine loaded blocks")
    end
  end

  --- @spec #terminate(): void
  function ic:terminate()
    local trace
    local span
    if Trace then
      trace = Trace:new('nokore_block_data/terminate')
    end
    for block_id, block in pairs(self.blocks) do
      if trace then
        span = trace:span_start('blocks/'..block_id)
      end
      self:persist_block(block, span)
      if span then
        span:span_end()
      end
    end
    if trace then
      trace:span_end()
    end
    self.blocks = {}
  end

  --- Register a callback that should be executed when a block is made available.
  ---
  --- @since "1.4.0"
  --- @spec #register_on_block_available(name: String, callback: Function/2): void
  function ic:register_on_block_available(name, callback)
    self.registered_on_block_available.register(name, callback)
  end

  --- Register a callback that should be executed when a block expires.
  ---
  --- @since "1.4.0"
  --- @spec #register_on_block_expired(name: String, callback: Function/2): void
  function ic:register_on_block_expired(name, callback)
    self.registered_on_block_expired.register(name, callback)
  end

  --- @spec #get_block(block_id: Integer): Block | nil
  function ic:get_block(block_id)
    return self.blocks[block_id]
  end

  --- @spec #get_block_at_pos(pos: Vector3): Block | nil
  function ic:get_block_at_pos(pos)
    return self.blocks[hash_node_position(pos)]
  end

  --- @spec #get_block_at_node_pos(pos: Vector3): Block | nil
  function ic:get_block_at_node_pos(pos)
    local x = floor(pos.x / 16)
    local y = floor(pos.y / 16)
    local z = floor(pos.z / 16)

    return self.blocks[hash_position(x, y, z)]
  end

  --- @spec #reduce_blocks(acc: Any, callback: Function/3): Any
  function ic:reduce_blocks(acc, callback)
    local should_break
    for block_id, block in pairs(self.blocks) do
      acc, should_break = callback(block_id, block, acc)
      if should_break then
        break
      end
    end
    return acc
  end

  --- @spec #on_player_leave(player: PlayerRef, timed_out: Boolean): void
  function ic:on_player_leave(player, timed_out)
    self.player_block_pos_cache[player:get_player_name()] = nil
  end

  --- @spec #update(dtime: Number, trace: Trace): void
  function ic:update(dtime, trace)
    self.monotonic_time = self.monotonic_time + dtime
    self.elapsed_since_last_update = self.elapsed_since_last_update + dtime

    if self.elapsed_since_last_update < 1 then
      return
    end
    self.elapsed_since_last_update = 0

    local pos
    local block_pos = { x = 0, y = 0, z = 0 }
    local nx, ny, nz
    local refresh_blocks
    local cached
    local item
    local block

    if get_active_blocks then
      for _, block_pos in ipairs(get_active_blocks()) do
        self:upsert_or_refresh_block(block_pos)
      end
    else
      local players = get_connected_players()
      local player_name
      if next(players) then
        for _, player in pairs(players) do
          player_name = player:get_player_name()
          pos = player:get_pos()

          -- neutral x, y, z
          nx = floor(pos.x / 16)
          ny = floor(pos.y / 16)
          nz = floor(pos.z / 16)

          cached = self.player_block_pos_cache[player_name]
          if cached then
            if cached.pos.x ~= nx or cached.pos.y ~= ny or cached.pos.z ~= nz then
              refresh_blocks = true
              cached.pos = {
                x = nx,
                y = ny,
                z = nz,
              }
            end
          else
            refresh_blocks = true
            cached = {
              pos = {
                x = nx,
                y = ny,
                z = nz,
              }
            }

            self.player_block_pos_cache[player_name] = cached
          end

          if not cached.expires_at or cached.expires_at < self.monotonic_time then
            -- the cache is stale, force refresh it
            cached.expires_at = nil
            refresh_blocks = true
          end

          if refresh_blocks then
            for y = -self.range,self.range do
              for z = -self.range,self.range do
                for x = -self.range,self.range do
                  block_pos.x = nx + x
                  block_pos.y = ny + y
                  block_pos.z = nz + z
                  block = self:upsert_or_refresh_block(block_pos)

                  -- try setting the caches expiration based on the block's expiration
                  -- this will force the player caches to refresh the blocks after some time
                  if cached.expires_at then
                    if block.expires_at < cached.expires_at then
                      cached.expires_at = block.expires_at
                    end
                  else
                    cached.expires_at = block.expires_at
                  end
                end
              end
            end
          end
        end
      end
    end

    while not self.next_expire_block:is_empty() do
      item = self.next_expire_block:peek()
      if item.expires_at <= self.monotonic_time then
        self.next_expire_block:pop()
        block = self.blocks[item.id]

        if block then
          if block.expires_at <= self.monotonic_time then
            self.expired_blocks[item.id] = true
          else
            self.next_expire_block:push({
              id = item.id,
              expires_at = block.expires_at,
            })
          end
        end
      else
        break
      end
    end

    while not self.next_persist_block:is_empty() do
      item = self.next_persist_block:peek()
      if item.next_persist_at <= self.monotonic_time then
        self.next_persist_block:pop()
        block = self.blocks[item.id]
        if block then
          if block.next_persist_at <= self.monotonic_time then
            self:persist_block(block)
          end
        end
      else
        break
      end
    end

    if next(self.expired_blocks) then
      local span
      for block_id,_ in pairs(self.expired_blocks) do
        if trace then
          span = trace:span_start("expired_block:" .. block_id)
        end
        block = self.blocks[block_id]
        self.blocks[block_id] = nil
        self:on_block_expired(block, span)
        self:persist_block(block, span)
        if span then
          span:span_end()
        end
      end
      self.expired_blocks = {}
    end
  end

  --- @spec #upsert_or_refresh_block(block_pos: Vector3): Block
  function ic:upsert_or_refresh_block(block_pos)
    local id = hash_node_position(block_pos)

    local block = self.blocks[id]
    if not block then
      -- core.log("debug", "initializing block data block_id=" .. id)
      local basename = "("..block_pos.x..","..block_pos.y..","..block_pos.z..")"

      local kv = KVStore:new()

      local filename

      if self.persistence_type == "MRSH" then
        filename = self.block_data_dir .. "/" .. basename .. ".mrsh"
        kv:marshall_load_file(filename)
      elseif self.persistence_type == "ASCI" then
        filename = self.block_data_dir .. "/" .. basename .. ".asci"
        kv:apack_load_file(filename)
      end

      block = {
        id = id,
        pos = vector.new(block_pos), -- copy the position
        basename = basename,
        filename = filename,
        kv = kv,
        assigns = {},
        persisted_at = self.monotonic_time,
        next_persist_at = self.monotonic_time + self.persist_interval,
        expires_at = self.monotonic_time + self.expires_duration,
      }

      self.blocks[id] = block
      self.next_persist_block:push({
        id = id,
        next_persist_at = block.next_persist_at,
      })
      self:on_block_available(block, nil)
    else
      block.expires_at = self.monotonic_time + self.expires_duration
    end
    self.next_expire_block:push({
      id = id,
      expires_at = block.expires_at,
    })

    return block
  end

  --- @spec #persist_block(Block, Trace): void
  function ic:persist_block(block, trace)
    local kv = block.kv
    -- in case someone deleted the block dir during runtime, this covers it up
    -- hopefully the engine is doing this efficiently.
    core.mkdir(self.block_data_dir)
    if kv.dirty then
      kv.dirty = false
      if self.persistence_type == "MRSH" then
        kv:marshall_dump_file(block.filename, trace)
      elseif self.persistence_type == "ASCI" then
        kv:apack_dump_file(block.filename, trace)
      end
    end
    block.persisted_at = self.monotonic_time
    block.next_persist_at = block.persisted_at + self.persist_interval
    self.next_persist_block:push({
      id = block.id,
      next_persist_at = block.next_persist_at,
    })
  end

  --- Callback when a block has been made available in the block data service.
  ---
  --- @since "1.4.0"
  --- @spec #on_block_available(block: Block, trace: Trace): void
  function ic:on_block_available(block, trace)
    self.registered_on_block_available.exec2(block, trace)
  end

  --- Internal callback when a block is considered expired.
  ---
  --- @since "1.4.0"
  --- @spec #on_block_expired(block: Block, trace: Trace): void
  function ic:on_block_expired(block, trace)
    self.registered_on_block_expired.exec2(block, trace)
  end
end

nokore_block_data.BlockDataService = BlockDataService
