--- SPDX-License-Identifier: Apache-2.0
--- SPDX-FileCopyrightText: 2026 druid.space

local KVStore = nokore_game_data.KVStore

local Luna = assert(foundation.com.Luna)

local ascii_file_pack = foundation.com.ascii_file_pack
local ascii_file_unpack = foundation.com.ascii_file_unpack

local MarshallValue = foundation.com.binary_types and foundation.com.binary_types.MarshallValue

local StringBuffer = assert(foundation.com.StringBuffer)

local case = Luna:new("nokore_game_data.KVStore")

case:describe("#initialize/0", function (t2)
  t2:test("initializes a new kv store", function (t3)
    local s = KVStore:new()

    t3:assert(s)
  end)
end)

case:describe("#copy/0", function (t2)
  t2:test("can make a shallow copy of the kv store", function (t3)
    local s = KVStore:new()
    s:put("a", "Hello")
    s:put("b", 12)
    s:put("c", true)
    local s2 = s:copy()

    t3:refute_raw_eq(s.data, s2.data)
    t3:assert_table_eq(s.data, s2.data)
  end)
end)

local function new_table_store(key, value)
  local kv = KVStore:new()
  kv:put(key, value or {})
  kv:clear_dirty()
  return kv
end

case:describe("#table_init/1", function (t2)
  t2:test("initializes a missing table and marks the store dirty", function (t3)
    local kv = KVStore:new()

    t3:assert_eq(kv:table_init("items"), true)
    t3:assert_deep_eq(kv:get("items"), {})
    t3:assert(kv.dirty)
  end)

  t2:test("does not replace an existing table", function (t3)
    local items = { "apple" }
    local kv = new_table_store("items", items)

    t3:assert_eq(kv:table_init("items"), false)
    t3:assert_raw_eq(kv:get("items"), items)
    t3:refute(kv.dirty)
  end)

  t2:test("returns nil for an existing non-table value", function (t3)
    local kv = KVStore:new()
    kv:put("items", 42)
    kv:clear_dirty()

    t3:refute(kv:table_init("items"))
    t3:assert_eq(kv:get("items"), 42)
    t3:refute(kv.dirty)
  end)
end)

case:describe("dumb set functions", function (t2)
  t2:test("inserts unique values and supports lookup", function (t3)
    local kv = new_table_store("items")

    t3:assert_raw_eq(kv:dset_insert("items", "apple"), kv)
    t3:assert(kv:dset_has_value("items", "apple"))
    t3:assert_eq(kv:dset_get("items", 1), "apple")
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:dset_insert("items", "apple")
    t3:assert_deep_eq(kv:get("items"), { "apple" })
    t3:refute(kv.dirty)
  end)

  t2:test("removes values without dirtying on a miss", function (t3)
    local kv = new_table_store("items", { "apple", "pear" })

    t3:assert_raw_eq(kv:dset_remove("items", "apple"), kv)
    t3:assert_deep_eq(kv:get("items"), { "pear" })
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:dset_remove("items", "missing")
    t3:refute(kv.dirty)
  end)

  t2:test("pops the last value", function (t3)
    local kv = new_table_store("items", { "apple", "pear" })

    t3:assert_eq(kv:dset_pop("items"), "pear")
    t3:assert_deep_eq(kv:get("items"), { "apple" })
    t3:assert(kv.dirty)

    kv:dset_pop("items")
    kv:clear_dirty()
    t3:refute(kv:dset_pop("items"))
    t3:refute(kv.dirty)
  end)

  t2:test("pops a value at an index", function (t3)
    local kv = new_table_store("items", { "apple", "pear", "plum" })

    t3:assert_eq(kv:dset_pop_at("items", 2), "pear")
    t3:assert_deep_eq(kv:get("items"), { "apple", "plum" })
    t3:assert(kv.dirty)

    kv:clear_dirty()
    t3:refute(kv:dset_pop_at("items", 20))
    t3:refute(kv.dirty)
  end)

  t2:test("rejects nil values and non-table storage", function (t3)
    local kv = new_table_store("items")
    local ok = pcall(kv.dset_insert, kv, "items", nil)
    t3:refute(ok)

    kv:put("items", "not a table")
    ok = pcall(kv.dset_has_value, kv, "items", "apple")
    t3:refute(ok)
  end)
end)

case:describe("dumb array functions", function (t2)
  t2:test("pushes and inserts values", function (t3)
    local kv = new_table_store("items", { "apple", "plum" })

    t3:assert_raw_eq(kv:darray_push("items", "quince"), kv)
    t3:assert_raw_eq(kv:darray_insert("items", 2, "pear"), kv)
    t3:assert_deep_eq(kv:get("items"), { "apple", "pear", "plum", "quince" })
    t3:assert(kv.dirty)
  end)

  t2:test("removes the first matching value", function (t3)
    local kv = new_table_store("items", { "apple", "pear", "apple" })

    t3:assert_raw_eq(kv:darray_remove("items", "apple"), kv)
    t3:assert_deep_eq(kv:get("items"), { "pear", "apple" })
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:darray_remove("items", "missing")
    t3:refute(kv.dirty)
  end)

  t2:test("deletes a value at an index", function (t3)
    local kv = new_table_store("items", { "apple", "pear", "plum" })

    t3:assert_raw_eq(kv:darray_delete("items", 2), kv)
    t3:assert_deep_eq(kv:get("items"), { "apple", "plum" })
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:darray_delete("items", 20)
    t3:refute(kv.dirty)
  end)

  t2:test("pops values from the end and at an index", function (t3)
    local kv = new_table_store("items", { "apple", "pear", "plum" })

    t3:assert_eq(kv:darray_pop_at("items", 2), "pear")
    t3:assert_eq(kv:darray_pop("items"), "plum")
    t3:assert_deep_eq(kv:get("items"), { "apple" })

    kv:darray_pop("items")
    kv:clear_dirty()
    t3:refute(kv:darray_pop("items"))
    t3:refute(kv:darray_pop_at("items", 1))
    t3:refute(kv.dirty)
  end)

  t2:test("supports value lookup and indexed access", function (t3)
    local kv = new_table_store("items", { "apple", "pear" })

    t3:assert(kv:darray_has_value("items", "pear"))
    t3:refute(kv:darray_has_value("items", "plum"))
    t3:assert_eq(kv:darray_get("items", 1), "apple")
    t3:refute(kv:darray_get("items", 20))
    t3:refute(kv.dirty)
  end)

  t2:test("rejects non-table storage", function (t3)
    local kv = KVStore:new()
    kv:put("items", "not a table")

    local ok = pcall(kv.darray_push, kv, "items", "apple")
    t3:refute(ok)
  end)
end)

case:describe("dumb map functions", function (t2)
  t2:test("puts, gets, and deletes entries", function (t3)
    local kv = new_table_store("items")

    t3:assert_raw_eq(kv:dmap_put("items", "apple", 3), kv)
    t3:assert_eq(kv:dmap_get("items", "apple"), 3)
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:dmap_put("items", "apple", 3)
    t3:refute(kv.dirty)

    t3:assert_raw_eq(kv:dmap_delete("items", "apple"), kv)
    t3:refute(kv:dmap_get("items", "apple"))
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:dmap_delete("items", "missing")
    t3:refute(kv.dirty)
  end)

  t2:test("updates entries lazily with the old value", function (t3)
    local kv = new_table_store("items", { apple = 2 })
    local old_value

    t3:assert_raw_eq(kv:dmap_put_lazy("items", "apple", function (old)
      old_value = old
      return old + 3
    end), kv)

    t3:assert_eq(old_value, 2)
    t3:assert_eq(kv:dmap_get("items", "apple"), 5)
    t3:assert(kv.dirty)

    kv:clear_dirty()
    kv:dmap_put_lazy("items", "apple", function (old)
      return old
    end)
    t3:refute(kv.dirty)
  end)

  t2:test("puts only new entries", function (t3)
    local kv = new_table_store("items", { apple = 2 })

    t3:assert_raw_eq(kv:dmap_put_new("items", "apple", 99), kv)
    t3:assert_eq(kv:dmap_get("items", "apple"), 2)
    t3:refute(kv.dirty)

    kv:dmap_put_new("items", "pear", 4)
    t3:assert_eq(kv:dmap_get("items", "pear"), 4)
    t3:assert(kv.dirty)
  end)

  t2:test("evaluates put-new callbacks only for missing entries", function (t3)
    local kv = new_table_store("items", { apple = 2 })
    local calls = 0

    kv:dmap_put_new_lazy("items", "apple", function ()
      calls = calls + 1
      return 99
    end)
    t3:assert_eq(calls, 0)
    t3:refute(kv.dirty)

    kv:dmap_put_new_lazy("items", "pear", function (old)
      calls = calls + 1
      t3:refute(old)
      return 4
    end)
    t3:assert_eq(calls, 1)
    t3:assert_eq(kv:dmap_get("items", "pear"), 4)
    t3:assert(kv.dirty)
  end)

  t2:test("rejects non-table storage", function (t3)
    local kv = KVStore:new()
    kv:put("items", "not a table")

    local ok = pcall(kv.dmap_get, kv, "items", "apple")
    t3:refute(ok)
  end)
end)

local METHODS = {
  {
    enabled = ascii_file_pack and ascii_file_unpack,
    uses_stream = true,
    load = "apack_load",
    dump = "apack_dump",
    load_file = "apack_load_file",
    dump_file = "apack_dump_file",
  },
  {
    enabled = MarshallValue,
    uses_stream = true,
    load = "marshall_load",
    dump = "marshall_dump",
    load_file = "marshall_load_file",
    dump_file = "marshall_dump_file",
  },
  -- {
  --   enabled = core.write_json and core.parse_json,
  --   uses_stream = false,
  --   load = "json_load",
  --   dump = "json_dump",
  --   load_file = "json_load_file",
  --   dump_file = "json_dump_file",
  -- },
  {
    enabled = core.serialize and core.deserialize,
    uses_stream = false,
    load = "deserialize_load",
    dump = "serialize_dump",
    load_file = "deserialize_load_file",
    dump_file = "serialize_dump_file",
  },
}

for _, def in ipairs(METHODS) do
  local desc = def.dump .. "|" .. def.load
  local file_desc = def.dump_file .. "|" .. def.load_file
  if def.enabled then
    case:describe(desc, function (t2)
      t2:test("can handle serializing an empty key value store", function (t3)
        local kv = KVStore:new()

        t3:refute(kv:get("key"))

        local blob
        local stream
        if def.uses_stream then
          stream = StringBuffer:new('', 'w')
          kv[def.dump](kv, stream)
          stream:close()
        else
          blob = kv[def.dump](kv)
        end

        -- create a new key value store
        local new_kv = KVStore:new()

        if def.uses_stream then
          stream:open('r')
          new_kv[def.load](kv, stream)
        else
          new_kv[def.load](kv, blob)
        end

        t3:refute(new_kv:get("key"))
      end)

      t2:test("can handle serializing a key-value store with various values", function (t3)
        local kv = KVStore:new()

        kv:put("boolean_true", true)
        kv:put("boolean_false", false)

        kv:put("n-1", -1)
        kv:put("n1", 1)
        kv:put("n256", 256)

        kv:put("string", "Hello, World")

        kv:put("empty_table", {})
        kv:put("table_array", {1, 2, 3})
        kv:put("table_map", { a = 1, b = 2, c = 3 })

        local blob
        local stream
        if def.uses_stream then
          stream = StringBuffer:new('', 'w')
          t3:assert(kv[def.dump](kv, stream))
          stream:close()
        else
          blob = t3:assert(kv[def.dump](kv))
        end

        -- create a new key value store
        local new_kv = KVStore:new()

        if def.uses_stream then
          stream:open('r')
          t3:assert(new_kv[def.load](new_kv, stream))
        else
          t3:assert(new_kv[def.load](new_kv, blob))
        end

        t3:assert_eq(new_kv:get("boolean_true"), true)
        t3:assert_eq(new_kv:get("boolean_false"), false)
        t3:assert_eq(new_kv:get("n-1"), -1)
        t3:assert_eq(new_kv:get("n1"), 1)
        t3:assert_eq(new_kv:get("n256"), 256)
        t3:assert_eq(new_kv:get("string"), "Hello, World")
        t3:assert_deep_eq(new_kv:get("empty_table"), {})
        t3:assert_deep_eq(new_kv:get("table_array"), {1, 2, 3})
        t3:assert_deep_eq(new_kv:get("table_map"), { a = 1, b = 2, c = 3})
      end)
    end)
  else
    core.log("warning", desc .. " unavailable")
  end

  if def.enabled then
    case:describe(file_desc, function (t2)
      local test_filename = foundation.com.path_join(core.get_worldpath(), "tmp/nokore_game_data_kv_test.blob")

      t2:test("can handle serializing an empty key value store", function (t3)
        local kv = KVStore:new()

        t3:refute(kv:get("key"))

        local bw, err = kv[def.dump_file](kv, test_filename)
        if err then
          error(err)
        end

        -- create a new key value store
        local new_kv = KVStore:new()

        new_kv[def.load_file](kv, test_filename)

        t3:refute(new_kv:get("key"))
      end)

      t2:test("can handle serializing a key-value store with various values", function (t3)
        local kv = KVStore:new()

        kv:put("boolean_true", true)
        kv:put("boolean_false", false)

        kv:put("n-1", -1)
        kv:put("n1", 1)
        kv:put("n256", 256)

        kv:put("string", "Hello, World")

        kv:put("empty_table", {})
        kv:put("table_array", {1, 2, 3})
        kv:put("table_map", { a = 1, b = 2, c = 3 })

        local bw
        local err
        bw, err = kv[def.dump_file](kv, test_filename)

        if err then
          error(err)
        end

        -- create a new key value store
        local new_kv = KVStore:new()

        new_kv[def.load_file](new_kv, test_filename)

        t3:assert_eq(new_kv:get("boolean_true"), true)
        t3:assert_eq(new_kv:get("boolean_false"), false)
        t3:assert_eq(new_kv:get("n-1"), -1)
        t3:assert_eq(new_kv:get("n1"), 1)
        t3:assert_eq(new_kv:get("n256"), 256)
        t3:assert_eq(new_kv:get("string"), "Hello, World")
        t3:assert_deep_eq(new_kv:get("empty_table"), {})
        t3:assert_deep_eq(new_kv:get("table_array"), {1, 2, 3})
        t3:assert_deep_eq(new_kv:get("table_map"), { a = 1, b = 2, c = 3})
      end)
    end)
  else
    core.log("warning", file_desc .. " unavailable")
  end
end

case:execute()
case:display_stats()
case:maybe_error()
