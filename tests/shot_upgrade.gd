extends SceneTree
# 视觉验证：局内三选一升级卡界面（暂停遮罩 + 三张按属性着色的卡 + 战场背景），
# 以及选完卡回到战场后 HUD 的「获得强化」toast 与 BUILD 计数。
# 注意：截图探针必须真渲染，不能加 --headless（dummy 渲染下 root.get_texture() 返回 null）。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	gs.save_path = "user://save_upgrade_shot.cfg"
	gs.start_run()
	var spawner := current_scene.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)

	# 遮罩后面留几只怪，画面才不像空地（静止摆拍，不参与 AI）
	var pool = get_first_node_in_group("enemy_pool")
	var walker = load("res://assets/data/enemy_walker.tres")
	var brute = load("res://assets/data/enemy_brute.tres")
	for item in [[walker, Vector2(-270, -80)], [walker, Vector2(310, 70)], [brute, Vector2(-130, 200)]]:
		var e: Node2D = pool.acquire(current_scene) as Node2D
		e.configure(item[0])
		e.global_position = item[1]
		e.set_physics_process(false)

	# 造一份「打到中段」的局内数据，让被遮罩压暗的 HUD 也有真实内容
	gs.score = 3820
	gs.kill_count = 68
	gs.combo = 12
	gs.survived_time = 96.4
	gs.weapon_level = 3
	gs.taken_upgrades = {"fire_rate": 2, "pierce": 1, "vitality": 1}
	gs.upgrades_taken = 4
	await create_timer(0.25, true, false, true).timeout

	# 攒满升级点 → 暂停开卡
	gs.crystals = gs.crystals_for_next() - 1
	gs.add_crystal()
	await create_timer(0.45, true, false, true).timeout
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("build/shot_upgrade_cards.png")

	# 选第二张：走真实鼠标点击（不是 emit_signal），顺带验证暂停中的输入链路
	var ui := current_scene.get_node_or_null("UILayer/UpgradeUI")
	var pos: Vector2 = ui.get_node("Center/Cards/Card1").get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	Input.parse_input_event(down)
	for i in 3:
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	Input.parse_input_event(up)
	await create_timer(0.35, true, false, true).timeout
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("build/shot_upgrade_toast.png")

	print("CLICK_RESUMED=", "true" if not ui.visible and not paused else "false")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.save_path = "user://save.cfg"
	print("SHOT_SAVED")
	quit()
