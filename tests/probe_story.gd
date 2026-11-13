extends SceneTree
# 剧情：模式开关、story.cfg 隔离、有限弹药、任务一到三的枪和敌人。
# 全程用临时存档，不写玩家的 save.cfg / career.cfg / story.cfg。
# StoryCopy 在运行时再 load，避免入口脚本的预加载把剧情存档脚本提前编译。

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

	# —— 任务解锁按顺序，四、五保持锁，下行卡只进 story.cfg ——
	story.clear_progress()
	story.load_disk()
	_expect(not story.chapter_unlocked("m1"), "m1 locked before prologue save")
	story.prologue_complete = true
	_expect(not story.chapter_unlocked("m1"), "m1 still locked without a save")
	story.has_save = true
	_expect(story.chapter_unlocked("m1") and not story.chapter_unlocked("m2"), "m1 opens after prologue save")
	story.mission1_complete = true
	_expect(story.chapter_unlocked("m2") and not story.chapter_unlocked("m3"), "m2 waits for mission 1")
	story.mission2_complete = true
	_expect(story.chapter_unlocked("m3") and not story.chapter_unlocked("m4"), "m3 opens, m4 stays locked")
	_expect(not story.chapter_unlocked("m5"), "m5 stays locked")
	story.owned_weapons = ["deagle", "shotgun", "firerifle", "flamethrower"]
	story.current_weapon = "shotgun"
	story.descent_card = true
	story.han_home = true
	story.add_file("patrol_log")
	story.add_file("stage_log")
	story.write_save()
	story.descent_card = false
	story.owned_weapons = ["deagle"]
	story.mission3_complete = true
	story.load_disk()
	_expect(story.descent_card and story.han_home, "descent card and han persist in story.cfg")
	_expect(story.owned_weapons.has("shotgun") and story.owned_weapons.has("firerifle") and story.owned_weapons.has("flamethrower"), "story weapons roundtrip")
	_expect(not story.mission3_complete, "unsaved mission flag does not stick")
	_expect(career.total_kills == career_before and gs.best_score == best_before, "story weapon save skips career")
	var copy_path := "res://scripts/story/Story" + "Copy.gd"
	var copy_src := FileAccess.get_file_as_string(copy_path)
	_expect(copy_src.contains("4471") and copy_src.contains("0063"), "locker and freezer codes")
	_expect(copy_src.contains("储物柜密码是我工号") and copy_src.contains("临时生物防护带"), "patrol log and qingchao letter")
	_expect(copy_src.contains("低于作业限值") and copy_src.contains("不要相信通知上的限值"), "mission 1 files")
	_expect(copy_src.contains("管壁内侧有移动的膜") and copy_src.contains("CUI-063") and copy_src.contains("后四位"), "leak note and stage code")
	_expect(copy_src.contains("暴露个体") and copy_src.contains("我送到侧门") and copy_src.contains("泵房更该先去"), "ethics memo and argument lines")

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

	# —— 任务一到三：定点枪、有限弹药、禁用变种、死亡不改已存档的枪 ——
	story.prologue_complete = true
	story.arrival_played = true
	story.mission1_complete = false
	story.mission2_complete = false
	story.mission3_complete = false
	story.descent_card = false
	story.han_home = false
	story.argument_seen = false
	story.ammo = 30
	story.health = 90.0
	story.owned_weapons = ["deagle"]
	story.current_weapon = "deagle"
	story.files_read.clear()
	story.write_save()
	story.load_disk()
	change_scene_to_file("res://scenes/story/Mission0" + "1.tscn")
	for i in 8:
		await process_frame
	_freeze_enemies()
	_expect(current_scene.name == "Mission01", "mission 1 scene")
	var m1 = current_scene
	var m1_player = get_first_node_in_group("player")
	_expect(m1_player.infinite_ammo == false and m1_player.ammo == 30, "mission 1 carries finite ammo")
	_expect(absf(m1_player.health - 90.0) < 0.1, "mission 1 carries health")
	_expect(_weapon_ids().has("shotgun") and not _weapon_ids().has(""), "shotgun is a placed pickup")
	var m1_names := _enemy_names()
	_expect(m1_names.has("漫游孢 Walker") and m1_names.has("疾走孢 Runner") and m1_names.has("潜伏孢 Lurker"), "mission 1 opening cast")
	_expect(not _has_banned(m1_names), "mission 1 has no brute or brood")
	m1.trigger_leak()
	m1_names = _enemy_names()
	_expect(m1_names.has("毒雾孢 Miasma"), "leak spawns one miasma")
	_expect(not _has_banned(m1_names) and not m1_names.has("分裂孢 Splitter") and not m1_names.has("酸液孢 Sprayer"), "mission 1 stays on the doc roster")
	for pk in get_nodes_in_group("pickup"):
		if pk.kind == "weapon" and pk.weapon_id == "shotgun":
			pk._collect()
			break
	_expect(gs.owned_weapons.has("shotgun"), "shotgun grant")
	m1.take_evidence()
	_expect(story.has_file("leak_note") and m1.evidence_done, "evidence file")
	m1.finish_mission()
	for i in 12:
		await process_frame
	_expect(current_scene.name == "Safehouse", "mission 1 returns to safehouse")
	_expect(story.mission1_complete and story.chapter_unlocked("m2"), "mission 1 unlocks mission 2")
	_expect(story.owned_weapons.has("shotgun"), "shotgun saved with the chapter")
	_expect(career.total_kills == career_before and gs.best_score == best_before, "mission 1 skips career")

	story.load_disk()
	change_scene_to_file("res://scenes/story/Mission0" + "2.tscn")
	for i in 8:
		await process_frame
	_freeze_enemies()
	_expect(current_scene.name == "Mission02", "mission 2 scene")
	_expect(get_first_node_in_group("player").infinite_ammo == false, "mission 2 finite ammo")
	_expect(_weapon_ids().has("firerifle"), "fire rifle placed in the hall")
	var m2_names := _enemy_names()
	_expect(m2_names.has("分裂孢 Splitter") and m2_names.has("潜伏孢 Lurker"), "mission 2 opening cast")
	_expect(not _has_banned(m2_names), "mission 2 has no brute or brood")
	current_scene.han_met = true
	current_scene.trigger_retreat()
	for i in 4:
		await process_frame
	_freeze_enemies()
	_expect(_enemy_names().has("毒针孢 Spitter"), "retreat wave uses spitters")
	_expect(not _has_banned(_enemy_names()), "retreat wave stays on the doc roster")
	gs.acquire_weapon("firerifle")
	_expect(gs.owned_weapons.has("firerifle"), "fire rifle grant before save")
	get_first_node_in_group("player").take_damage(10000.0)
	await create_timer(1.2, true, false, true).timeout
	story.return_from_death()
	for i in 12:
		await process_frame
	_expect(current_scene.name == "Safehouse", "mission 2 death returns home")
	story.load_disk()
	_expect(story.owned_weapons.has("shotgun") and not story.owned_weapons.has("firerifle"), "unsaved fire rifle is lost, shotgun stays")
	_expect(story.mission1_complete and not story.mission2_complete, "death does not clear mission 1")
	_expect(career.total_runs == runs_before and gs.best_score == best_before, "mission 2 death skips career")

	change_scene_to_file("res://scenes/story/Mission0" + "3.tscn")
	for i in 8:
		await process_frame
	_freeze_enemies()
	_expect(current_scene.name == "Mission03", "mission 3 scene")
	_expect(get_first_node_in_group("player").infinite_ammo == false, "mission 3 finite ammo")
	_expect(_weapon_ids().has("flamethrower"), "flamethrower is a direct cabinet pickup")
	current_scene.trigger_hall()
	current_scene.trigger_prep()
	var m3_names := _enemy_names()
	_expect(m3_names.has("毒雾孢 Miasma") and m3_names.has("酸液孢 Sprayer") and m3_names.has("毒针孢 Spitter"), "mission 3 roster")
	_expect(not _has_banned(m3_names), "mission 3 has no brute or brood")
	gs.acquire_weapon("flamethrower")
	_expect(gs.owned_weapons.has("flamethrower"), "flamethrower grant")

	story.mission2_complete = true
	story.han_home = true
	story.argument_seen = false
	story.arrival_played = true
	story.pending_chapter = ""
	story.write_save()
	story.load_disk()
	change_scene_to_file("res://scenes/story/Safe" + "house.tscn")
	for i in 10:
		await process_frame
	_expect(current_scene.name == "Safehouse", "safehouse for the argument")
	current_scene._on_mission("m3")
	await process_frame
	var gate := ""
	for entry in current_scene._session.dialogue._lines:
		gate += str(entry.text)
	_expect(gate.contains("泵房更该先去") and gate.contains("我送到侧门"), "argument then still leaves for qingchao")
	current_scene._session.dialogue._index = current_scene._session.dialogue._lines.size()
	current_scene._session.dialogue._show_current()
	for i in 12:
		await process_frame
	_expect(current_scene.name == "Mission03", "argument does not soft-lock")

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

func _freeze_enemies() -> void:
	for e in get_nodes_in_group("enemy"):
		e.set_physics_process(false)

func _weapon_ids() -> Dictionary:
	var ids: Dictionary = {}
	for pk in get_nodes_in_group("pickup"):
		if str(pk.kind) == "weapon":
			ids[str(pk.weapon_id)] = true
	return ids

func _enemy_names() -> Dictionary:
	var names: Dictionary = {}
	for e in get_nodes_in_group("enemy"):
		if e.get("stats") == null:
			continue
		if not e.get("active") and not str(e.stats.display_name).contains("毒雾"):
			continue
		names[str(e.stats.display_name)] = true
	return names

func _has_banned(names: Dictionary) -> bool:
	for key in names.keys():
		var who: String = str(key)
		if who.contains("肿胀孢") or who.contains("母巢孢"):
			return true
	return false

func _expect(ok: bool, label: String) -> void:
	print("CHECK ", label, " ", "PASS" if ok else "FAIL")
	if not ok:
		fail_count += 1
