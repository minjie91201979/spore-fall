extends SceneTree
# 剧情第一期：模式开关、story.cfg 隔离、有限弹药、序章敌人种类。
# 全程用临时存档，不写玩家的 save.cfg / career.cfg / story.cfg。

var fail_count := 0

func _initialize() -> void:
	var gs: Node = get_root().get_node("GameState")
	var career: Node = get_root().get_node("Career")
	var story: Node = get_root().get_node("StoryState")
	career.save_path = "user://career_story_probe.cfg"
	gs.save_path = "user://save_story_probe.cfg"
	story.save_path = "user://story_probe.cfg"
	if FileAccess.file_exists(story.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(story.save_path))
	story.load_disk()
	var career_before: int = career.total_kills
	var runs_before: int = career.total_runs
	var best_before: int = gs.best_score

	# —— 生存三选一仍会触发；剧情只加晶体 ——
	gs.start_run()
	var upgrades: Array = []
	gs.upgrade_ready.connect(func(_c): upgrades.append(1))
	var need: int = gs.crystals_for_next()
	for i in need:
		gs.add_crystal()
	print("SURVIVAL_LEVEL=", gs.weapon_level, " UPS=", upgrades.size(), " CRYSTALS=", gs.crystals, " MODE=", gs.run_mode)
	_expect(gs.weapon_level == 2, "survival crystal still levels weapon")
	_expect(upgrades.size() == 1, "survival upgrade signal still fires")
	gs.begin_story()
	var story_upgrades := 0
	gs.upgrade_ready.connect(func(_c): story_upgrades += 1)
	for i in 12:
		gs.add_crystal()
	_expect(story_upgrades == 0 and gs.weapon_level == 1, "story skips upgrade cards")
	_expect(gs.run_mode == "story" and gs.is_story(), "story mode flag")

	# —— 击杀不进生涯 ——
	gs.register_kill(10)
	gs.register_kill(10)
	_expect(career.total_kills == career_before, "story kills skip career")
	_expect(gs.score == 0, "story kills skip score")

	# —— 存档往返，且不碰到生涯文件 ——
	story.prologue_complete = true
	story.ammo = 17
	story.health = 80.0
	story.crystals = 3
	story.herbs = 1
	story.radio_contacted = true
	story.add_file("gate_log")
	story.owned_weapons = ["deagle"]
	story.current_weapon = "deagle"
	story.write_save()
	story.ammo = 0
	story.prologue_complete = false
	story.load_disk()
	_expect(story.has_save and story.prologue_complete and story.ammo == 17, "story.cfg roundtrip")
	_expect(story.has_file("gate_log") and story.herbs == 1 and story.crystals == 3, "story.cfg fields")
	_expect(career.total_runs == runs_before and career.total_kills == career_before, "career untouched")
	_expect(gs.best_score == best_before, "best score untouched")

	# —— 序章场景：飞鹰、24 发、只有三种孢 ——
	story.load_disk()
	story.carry_loadout = false
	story.replaying = false
	change_scene_to_file("res://scenes/story/Prologue.tscn")
	for i in 20:
		await process_frame
	_expect(current_scene.name == "Prologue", "prologue scene")
	_expect(gs.is_story() and gs.is_running, "prologue is a story session")
	var hero = get_first_node_in_group("player")
	_expect(hero != null and hero.infinite_ammo == false and hero.ammo == 24, "prologue ammo 24")
	_expect(gs.owned_weapons.size() == 1 and gs.owned_weapons[0] == "deagle", "prologue deagle only")
	var names: Dictionary = {}
	for e in get_nodes_in_group("enemy"):
		if not e.get("active") or e.get("stats") == null:
			continue
		names[str(e.stats.display_name)] = true
	print("ENEMY_NAMES=", names.keys())
	_expect(names.has("漫游孢 Walker") and names.has("疾走孢 Runner") and names.has("肿胀孢 Brute"), "three prologue variants")
	_expect(names.size() == 3, "no other variants in prologue")
	_expect(career.total_kills == career_before, "prologue boot did not record kills")
	hero.control_mode = 0
	hero.fire()
	_expect(hero.ammo == 23, "finite ammo spends a round")
	hero.ammo = 0
	hero._fire_cd = 0.0
	hero.fire()
	_expect(hero.ammo == 0, "empty mag does not go negative")
	hero.infinite_ammo = true
	hero.ammo = 5
	hero._fire_cd = 0.0
	hero.fire()
	_expect(hero.ammo == 5, "infinite ammo does not spend")
	hero.infinite_ammo = false
	hero.control_mode = 2

	# —— 倒下回安全屋语义：不写生存结算 ——
	var failed: Array = []
	gs.story_failed.connect(func(): failed.append(true))
	hero.take_damage(10000.0)
	await create_timer(1.2, true, false, true).timeout
	_expect(not failed.is_empty(), "story death emits story_failed")
	_expect(gs.best_score == best_before, "story death skips best score")
	_expect(career.total_runs == runs_before, "story death skips career run")
	var death_ui = get_first_node_in_group("story_death")
	_expect(death_ui != null and death_ui.visible, "story death panel")
	_expect(current_scene.get_node_or_null("UILayer/GameOver") == null, "no survival game over")
	story.return_from_death()
	for i in 20:
		await process_frame
	_expect(current_scene != null and current_scene.name == "Safehouse", "death returns to safehouse")

	# —— 回到 Arena 仍是无限弹药 ——
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 20:
		await process_frame
	var arena_player = get_first_node_in_group("player")
	_expect(gs.run_mode == "survival" and not gs.is_story(), "arena restores survival")
	_expect(arena_player != null and arena_player.infinite_ammo == true, "arena infinite ammo")
	_expect(gs.is_running, "arena run started")

	story.clear_progress()
	print("FAILS=", fail_count)
	if fail_count == 0:
		print("OK")
	quit()

func _expect(ok: bool, label: String) -> void:
	print("CHECK ", label, " ", "PASS" if ok else "FAIL")
	if not ok:
		fail_count += 1
