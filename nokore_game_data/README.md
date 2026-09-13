# Nokore Game Data

Some helper modules for dealing with various bits and pieces of game data.

Provides the `nokore_game_data.KVStore` which may be used by other services or mods that need richer key-value storage facilities with built-in persistence.

## Usage

```lua
local my_kv = nokore.KVStore:new()

my_kv:put("key", 1)
my_kv:put("key2", "value")
my_kv:put("key3", {
  a = 1,
  b = "Hello",
  c = true,
  d = {
    1, 2, 3
  }
})

my_kv.dirty -- => true
```

The KVStore provides a few persistence functions out of the box, but does not automatically persist.

The function is `<method>_{dump,load,dump_file,load_file}`.

Out of the box, the following methods are provided:
* `apack` - when `foundation_ascii_pack` is present
* `json` - using core.write_json
* `marshall` - when `foundation_binary` is present using MarshallValue
* `serialize` - using core.serialize

```lua
my_kv:marshall_dump_file(core.get_worldpath() .. "/my_kv.bin")
```
