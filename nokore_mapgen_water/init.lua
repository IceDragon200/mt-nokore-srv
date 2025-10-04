--
-- NoKore - Mapgen Water
--
-- Adds the water nodes as mapgen aliases
foundation.new_module("nokore_mapgen_water", "0.1.0")

if nokore.game_id == "default" then
  -- skip for MTG
  return
end

core.register_alias("mapgen_water_source", "nokore_world_water:fresh_water_source")
core.register_alias("mapgen_river_water_source", "nokore_world_water:river_water_source")
