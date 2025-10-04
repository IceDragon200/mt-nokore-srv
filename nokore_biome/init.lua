--
-- NoKore - Biome
--
-- This module handles clearing the core biomes before allowing the other biome mods
-- from updating it
foundation.new_module("nokore_biome", "0.1.0")

if nokore.game_id == "default" then
  -- skip for MTG
  return
end

core.clear_registered_biomes()
