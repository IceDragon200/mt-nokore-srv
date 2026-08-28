# NoKore Common

Common module for NoKore mods.

## API

### Callbacks

As of version 1.1.0, `nokore_common`, now provides a utility function for creating a new callback table.

This is a helper for quickly creating a table that can register and execute callbacks.

```lua
local my_callbacks = nokore_common.new_callbacks()

my_callbacks.register("my_callback", function ()
  -- Do whatever you like
end)

-- execute all callbacks by pairs order without arguments
my_callbacks.exec0()

-- execute all callbacks by pairs order with arguments ()
my_callbacks.exec(...)

-- execute all callbacks by in order of registration without arguments
my_callbacks.ordered_exec0()

-- execute all callbacks by in order of registration with arguments
my_callbacks.ordered_exec(...)
```

If anything more complex is needed, it's best to write it yourself.

Why have execN variants you may ask? Optimization, vargs can't be reliably optimized in some cases, so its best to pick the execution model that fits your needs.

At the time of this writing: `exec1`, `exec2` and `exec3` (along with its ordered variants) are provided by default.

### Dig Class

```lua
nokore.dig_class(material_class)

nokore.dig_class("hand")
nokore.dig_class("wme")
-- ...
nokore.dig_class("nano_element")

--- Usage
core.register_node("my_mod:my_node", {
  groups = {
    cracky = nokore.dig_class("wme")
  }
})
```
