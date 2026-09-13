--- SPDX-License-Identifier: Apache-2.0
--- SPDX-FileCopyrightText: 2026 druid.space

--
-- Key-Value Store
--
-- Simple class for defining a key-value store
local assertions = assert(foundation.com.assertions)
local table_insert = assert(table.insert)
local table_remove = assert(table.remove)
local table_includes_value = assert(foundation.com.table_includes_value)
local table_key_of = assert(foundation.com.table_key_of)
local table_keys = assert(foundation.com.table_keys)
local table_values = assert(foundation.com.table_values)

--- @namespace nokore

--- @class KVStore
local KVStore = foundation.com.Class:extends("nokore.KVStore")
do
  local ic = KVStore.instance_class

  --- @type Key: String | Integer

  --- @type Value: Integer | String | Table | Boolean

  --- @override
  --- @spec #initialize(): void
  function ic:initialize()
    ic._super.initialize(self)

    --- @member data: Record<Key, Any>
    self.data = {}

    --- @member dirty: Boolean
    self.dirty = false
  end

  --- @override
  --- @spec #initialize_copy(other: KVStore): void
  function ic:initialize_copy(other)
    ic._super.initialize_copy(self, other)
    self.data = {}
    for key, value in pairs(other.data) do
      self.data[key] = value
    end
  end

  --- @spec #clear(): self
  function ic:clear()
    -- it is faster to replace the data than it would be to nullify each pair
    self.data = {}
    self.dirty = true
    return self
  end

  --- @spec #mark_dirty(): self
  function ic:mark_dirty()
    self.dirty = true
    return self
  end

  --- @since "0.8.0"
  --- @spec #clear_dirty(): self
  function ic:clear_dirty()
    self.dirty = false
    return self
  end

  --- @spec #get(key: Key, default: Value): Value
  function ic:get(key, default)
    local value = self.data[key]
    if value == nil then
      return default
    end
    return value
  end

  --- @spec #get_lazy(key: Key, Function/0): Value
  function ic:get_lazy(key, callback)
    local value = self.data[key]

    if value == nil then
      return callback()
    end

    return value
  end

  --- @spec #keys(): Key[]
  function ic:keys()
    return table_keys(self.data)
  end

  --- @spec #values(): Value[]
  function ic:values()
    return table_values(self.data)
  end

  --- @spec #has_key(key: Key): Boolean
  function ic:has_key(key)
    return self.data[key] ~= nil
  end

  --- Put value at specified key
  ---
  --- @spec #put(key: Key, Value): self
  function ic:put(key, value)
    local old_value = self.data[key]
    if old_value ~= value then
      self.data[key] = value
      self.dirty = true
    end
    return self
  end

  --- Put a value at specified key (if it doesn't already exist)
  ---
  --- @since "0.6.0"
  --- @spec #put_new(Key, Value): self
  function ic:put_new(key, value)
    if self.data[key] == nil then
      return self:put(key, value)
    end
    return self
  end

  --- Put a value evaluated from given function at specified key (if it doesn't already exist)
  ---
  --- @since "0.6.0"
  --- @spec #put_new_lazy(key: Key, callback: Function/0): self
  function ic:put_new_lazy(key, callback)
    if self.data[key] == nil then
      return self:put(key, callback())
    end
    return self
  end

  --- Put multiple values from given Table into store
  ---
  --- @since "0.7.0"
  --- @spec #put_all(Table): self
  function ic:put_all(tab)
    local old_value
    for key, value in pairs(tab) do
      old_value = self.data[key]
      if old_value ~= value then
        self.data[key] = value
        self.dirty = true
      end
    end
    return self
  end

  --- Update an key-value pair regardless of if it exists.
  ---
  --- Usage:
  ---
  ---     upsert_lazy("my_key", function (old_value)
  ---       ... do something with old_value
  ---       return new_value
  ---     end)
  ---
  --- @spec #upsert_lazy(Key, Function/1): self
  function ic:upsert_lazy(key, callback)
    local old_value = self.data[key]
    self.data[key] = callback(self.data[key])
    if old_value ~= self.data[key] then
      self.dirty = true
    end
    return self
  end

  --- Update an existing key-value pair.
  ---
  --- Usage:
  ---
  ---     update_lazy("my_key", function (old_value)
  ---       ... do something with old_value
  ---       return new_value
  ---     end)
  ---
  --- @spec #update_lazy(Key, Function/1): self
  function ic:update_lazy(key, callback)
    local old_value = self.data[key]
    if old_value ~= nil then
      self.data[key] = callback(self.data[key])
      if old_value ~= self.data[key] then
        self.dirty = true
      end
    end
    return self
  end

  --- Increment specified key by given amount, this is intended to replace use cases that would
  --- do a get and put to increase a number field.
  --- Note that is the field was not set, it will assume the value was zero to begin with.
  ---
  --- @since "0.9.0"
  --- @spec #increment(key: Key, amount: Number): (Number, self)
  function ic:increment(key, amount)
    self.data[key] = (self.data[key] or 0) + amount
    self.dirty = true
    return self.data[key], self
  end

  --- Decrement specified key by given amount, this is intended to replace use cases that would
  --- do a get and put to decrease a number field.
  --- Note that is the field was not set, it will assume the value was zero to begin with.
  ---
  --- @since "0.9.0"
  --- @spec #decrement(key: Key, amount: Number): (Number, self)
  function ic:decrement(key, amount)
    self.data[key] = (self.data[key] or 0) - amount
    self.dirty = true
    return self.data[key], self
  end

  --- @spec #delete(Key): self
  function ic:delete(key)
    if self.data[key] ~= nil then
      self.data[key] = nil
      self.dirty = true
    end
    return self
  end

  --- Attempts to initialize a table at the specified key, if the table
  --- was newly initialized, `true` is returned, if a table already exists, false is returned,
  --- all other values will return nil.
  --- This is intended to be used with `dumb` table structures to optionally initialize them.
  --- @since "0.12.0"
  --- @spec #table_init(key: Key): nil | Boolean
  function ic:table_init(key)
    local tab = self.data[key]
    if tab == nil then
      self.data[key] = {}
      self.dirty = true
      return true
    elseif type(tab) == "table" then
      return false
    end
    return nil
  end

  --
  -- Dumb Set Functions
  --

  --- @since "0.12.0"
  --- @raises
  --- @spec #dset_insert(key: Key, value: Any): self
  function ic:dset_insert(key, value)
    assert(value ~= nil)
    local set = self.data[key]
    assertions.is_table(set, "expected key to contain a table")
    if not table_includes_value(set, value) then
      table_insert(set, value)
      self.data[key] = set
      self.dirty = true
    end
    return self
  end

  --- Removes specified value from the set, returning self regardless of success.
  --- This function WILL raise if the data's value is not a table.
  --- @since "0.12.0"
  --- @raises
  --- @spec #dset_remove(key: Key, value: Any): self
  function ic:dset_remove(key, value)
    local set = self.data[key]
    assertions.is_table(set, "expected key to contain a table")
    local idx = table_key_of(set, value)
    if idx then
      table_remove(set, idx)
      self.dirty = true
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dset_pop(key: Key): nil | Any
  function ic:dset_pop(key)
    local set = self.data[key]
    assertions.is_table(set, "expected key to contain a table")
    local len = #set
    if len > 0 then
      local value = table_remove(set, len)
      self.dirty = true
      return value
    end
    return nil
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dset_pop_at(key: Key, idx: Integer): nil | Any
  function ic:dset_pop_at(key, idx)
    local set = self.data[key]
    assertions.is_table(set, "expected key to contain a table")
    if set[idx] ~= nil then
      local value = table_remove(set, idx)
      self.dirty = true
      return value
    end
    return nil
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dset_has_value(key: Key, value: Any): Boolean
  function ic:dset_has_value(key, value)
    local set = self.data[key]
    assertions.is_table(set, "expected key to contain a table")
    local idx = table_key_of(set, value)
    return idx ~= nil
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dset_get(key: Key, idx: Integer): Any
  function ic:dset_get(key, idx)
    local set = self.data[key]
    assertions.is_table(set, "expected key to contain a table")
    return set[idx]
  end

  --
  -- Dumb Array Functions
  --

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_insert(key: Key, idx: Integer, value: Any): self
  function ic:darray_insert(key, idx, value)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    table_insert(arr, idx, value)
    self.data[key] = arr
    self.dirty = true
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_remove(key: Key, value: Any): self
  function ic:darray_remove(key, value)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    local idx = table_key_of(arr, value)
    if idx then
      table_remove(arr, idx)
      self.dirty = true
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_push(key: Key, value: Any): self
  function ic:darray_push(key, value)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    table_insert(arr, value)
    self.data[key] = arr
    self.dirty = true
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_delete(key: Key, idx: Integer): self
  function ic:darray_delete(key, idx)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    if arr[idx] ~= nil then
      table_remove(arr, idx)
      self.dirty = true
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_pop_at(key: Key, idx: Integer): nil | Any
  function ic:darray_pop_at(key, idx)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    if arr[idx] ~= nil then
      local value = table_remove(arr, idx)
      self.dirty = true
      return value
    end
    return nil
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_pop(key: Key): nil | Any
  function ic:darray_pop(key)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    local len = #arr
    if len > 0 then
      local value = table_remove(arr, len)
      self.dirty = true
      return value
    end
    return nil
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_has_value(key: Key, value: Any): Boolean
  function ic:darray_has_value(key, value)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    local idx = table_key_of(arr, value)
    return idx ~= nil
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #darray_get(key: Key, idx: Integer): Any
  function ic:darray_get(key, idx)
    local arr = self.data[key]
    assertions.is_table(arr, "expected key to contain a table")
    return arr[idx]
  end

  --
  -- Dumb Map Function
  --

  --- @since "0.12.0"
  --- @raises
  --- @spec #dmap_put(key: Key, k: Any, v: Any): self
  function ic:dmap_put(key, k, v)
    local map = self.data[key]
    assertions.is_table(map, "expected key to contain a table")
    local o = map[k]
    if o ~= v then
      map[k] = v
      self.data[key] = map
      self.dirty = true
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dmap_put_lazy(key: Key, k: Any, callback: Function/1): self
  function ic:dmap_put_lazy(key, k, callback)
    local map = self.data[key]
    assertions.is_table(map, "expected key to contain a table")
    local o = map[k]
    local v = callback(o)
    if o ~= v then
      map[k] = v
      self.data[key] = map
      self.dirty = true
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dmap_put_new(key: Key, k: Any, v: Any): self
  function ic:dmap_put_new(key, k, v)
    local map = self.data[key]
    assertions.is_table(map, "expected key to contain a table")
    local o = map[k]
    if o == nil then
      if o ~= v then
        map[k] = v
        self.data[key] = map
        self.dirty = true
      end
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dmap_put_new_lazy(key: Key, k: Any, callback: Function/1): self
  function ic:dmap_put_new_lazy(key, k, callback)
    local map = self.data[key]
    assertions.is_table(map, "expected key to contain a table")
    local o = map[k]
    if o == nil then
      local v = callback(o)
      if o ~= v then
        map[k] = v
        self.data[key] = map
        self.dirty = true
      end
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dmap_delete(key: Key, k: Any): self
  function ic:dmap_delete(key, k)
    local map = self.data[key]
    assertions.is_table(map, "expected key to contain a table")
    local o = map[k]
    if o ~= nil then
      map[k] = nil
      self.dirty = true
    end
    return self
  end

  --- @since "0.12.0"
  --- @raises
  --- @spec #dmap_get(key: Key, k: Any): self
  function ic:dmap_get(key, k)
    local map = self.data[key]
    assertions.is_table(map, "expected key to contain a table")
    return map[k]
  end
end

nokore_game_data.KVStore = KVStore
