--
-- NoKore - Mapgen
--
-- This module handles clearing the core mapgen before allowing the other mapgen mods to
-- begin updating it.
-- This ensures that mapgen starts from a clean slate
local mod = foundation.new_module("nokore_mapgen", "0.1.0")

local mgname = core.get_mapgen_setting("mg_name")

mod.enable_trees = false
mod.enable_giant_mushrooms = false
mod.mapgen_name = mgname

if mod.mapgen_name == "singlenode" then
  --
  mod.is_singlenode = true
else
  mod.enable_trees = true
  mod.enable_giant_mushrooms = false
  mod.tree_seed = 0x65674436
  mod.seed_giant_mushroom = 0x4D555348
end

-- Clear existing registration
if nokore.game_id ~= "default" then
  -- skip for MTG, but clear for every other game
  core.clear_registered_ores()
  core.clear_registered_decorations()
end
