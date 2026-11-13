extends Node
# 武器升级链路：晶体门槛 6/8/10… → 等级刷新 → LV3 两条弹道。
# 旧版按 3/4/5 颗断言，并且把截图写死在某台机器的桌面路径上。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	if get_tree().get_first_node_in_group("player") == null:
		var arena: Node = load("res://scenes/world/Arena.tscn").instantiate()
		get_tree().root.add_child(arena)
		await get_tree().physics_frame
	var player: Node = get_tree().get_first_node_in_group("player")
	var ok := false
	if player == null:
		print("PROBE FAIL no player")
	else:
		GameState.start_run()
		await get_tree().process_frame
		print("PROBE lv=%d interval=%.3f dmg=%.1f proj=%d next=%d" % [
			GameState.weapon_level, player.fire_interval, player.bullet_damage,
			player.projectile_count, GameState.crystals_for_next()])
		for i in 5:
			GameState.add_crystal()
		var before_level: bool = GameState.weapon_level == 1 and GameState.crystals == 5
		GameState.add_crystal()
		# 攒满会暂停弹三选一；等级和弹道数在信号里同步刷新，不必等帧（暂停时帧信号不可靠）
		var lv2: bool = before_level and GameState.weapon_level == 2 and GameState.crystals == 0 \
			and GameState.crystals_for_next() == 8 and player.projectile_count == 1
		print("PROBE after6 lv=%d crystals=%d proj=%d ok=%s" % [
			GameState.weapon_level, GameState.crystals, player.projectile_count, lv2])
		for i in 8:
			GameState.add_crystal()
		print("PROBE after6+8 lv=%d proj=%d" % [GameState.weapon_level, player.projectile_count])
		for b in get_tree().get_nodes_in_group("player_bullet"):
			if b.has_method("_release"):
				b._release()
		player._fire_cd = 0.0
		var before: int = get_tree().get_nodes_in_group("player_bullet").size()
		player.fire()
		var after: int = get_tree().get_nodes_in_group("player_bullet").size()
		print("PROBE fired bullets %d -> %d (expect +2)" % [before, after])
		ok = lv2 and GameState.weapon_level == 3 and player.projectile_count == 2 and (after - before) == 2
	print("PROBE %s" % ("PASS" if ok else "FAIL"))
	_save_shot("weapon_probe.png")
	get_tree().paused = false
	get_tree().quit(0 if ok else 1)

func _save_shot(file_name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)
	var tex := get_viewport().get_texture()
	if tex == null:
		print("PROBE shot skipped")
		return
	var img := tex.get_image()
	if img:
		img.save_png(dir.path_join(file_name))
