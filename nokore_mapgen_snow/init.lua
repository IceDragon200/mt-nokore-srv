--
-- NoKore - Mapgen Snow
--
-- Adds the snow nodes as mapgen aliases
foundation.new_module("nokore_mapgen_snow", "0.1.0")

if nokore.game_id == "default" then
  -- skip for MTG
  return
end

-- Mapgen V6
core.register_alias("mapgen_snow", "nokore_world_snow:snow")
core.register_alias("mapgen_dirt_with_snow", "nokore_world_snow:dirt_with_snow")
core.register_alias("mapgen_snowblock", "nokore_world_snow:snow_block")
core.register_alias("mapgen_ice", "nokore_world_snow:ice")
