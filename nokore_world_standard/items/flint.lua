local mod = assert(nokore_world_standard)

mod:register_craftitem("flint", {
  description = mod.S("Flint"),

  groups = {
    flint = 1,
  },

  inventory_image = "world_flint.png",
})
