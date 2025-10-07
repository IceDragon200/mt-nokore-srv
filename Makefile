RELEASE_DIR=${TMP_DIR}/nokore

.PHONY : luacheck
luacheck:
	luacheck .

# Release step specifically when the modpack is under a game, this will copy
# the modpack to the TMP_DIR
.PHONY: prepare.release
prepare.release:
	mkdir -p "${RELEASE_DIR}"

	cp -r --parents nokore_block_data "${RELEASE_DIR}"
	cp -r --parents nokore_common "${RELEASE_DIR}"
	cp -r --parents nokore_creative "${RELEASE_DIR}"
	cp -r --parents nokore_entity_walkover "${RELEASE_DIR}"
	cp -r --parents nokore_game_data "${RELEASE_DIR}"
	cp -r --parents nokore_player_data "${RELEASE_DIR}"
	cp -r --parents nokore_player_hud "${RELEASE_DIR}"
	cp -r --parents nokore_player_inv "${RELEASE_DIR}"
	cp -r --parents nokore_player_inv10 "${RELEASE_DIR}"
	cp -r --parents nokore_player_owned "${RELEASE_DIR}"
	cp -r --parents nokore_player_service "${RELEASE_DIR}"
	cp -r --parents nokore_player_spawn "${RELEASE_DIR}"
	cp -r --parents nokore_player_stats "${RELEASE_DIR}"
	cp -r --parents nokore_player_stats_observer "${RELEASE_DIR}"
	cp -r --parents nokore_proxy "${RELEASE_DIR}"
	cp -r --parents nokore_stairs "${RELEASE_DIR}"
	cp -r --parents nokore_treasure "${RELEASE_DIR}"
	cp -r --parents nokore_ui "${RELEASE_DIR}"
	cp -r --parents nokore_world_kv "${RELEASE_DIR}"

	cp LICENSE "${RELEASE_DIR}"
	cp modpack.conf "${RELEASE_DIR}"
	cp README.md "${RELEASE_DIR}"
