extends SceneTree
# 武器系统视觉验证：武器栏 5 槽 + 激光穿透光束 + 燃烧弹火光，截屏 build/shot_weapons.png
# 用法（必须带窗口，不能 --headless）：
#   Godot.exe --path . --script tests/shot_weapons.gd

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")   # autoload 在 root 下
	if gs == null:
		# 兜底：SceneTree 模式下 autoload 名即节点名
		gs = root.get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var spawner = current_scene.get_node_or_null("Spawner")
	var p = get_first_node_in_group("player")
	if spawner == null or p == null:
		print("SETUP_FAILED")
		quit()
		return
	var pool = get_first_node_in_group("enemy_pool")

	# 授予全部武器（武器栏 5 格全亮），切到激光枪
	for wid in ["shotgun", "firerifle", "flamethrower", "laser"]:
		gs.acquire_weapon(wid)
	gs.switch_weapon("laser")
	gs.score = 12400
	gs.combo = 7

	# 一排杂兵站在玩家右侧同一直线上：激光应该串成一串
	var enemies: Array = []
	for i in 4:
		var e: Node2D = pool.acquire(current_scene)
		e.configure(load("res://assets/data/enemy_walker.tres"))
		e.global_position = p.global_position + Vector2(150.0 + 55.0 * i, -20.0)
		e.set_physics_process(false)   # 冻结当靶
		enemies.append(e)

	# 火弹枪的火光点缀：下方一只敌人被火弹点燃
	var e_fire: Node2D = pool.acquire(current_scene)
	e_fire.configure(load("res://assets/data/enemy_walker.tres"))
	e_fire.global_position = p.global_position + Vector2(-180.0, 80.0)
	e_fire.set_physics_process(false)

	await create_timer(0.3, true, false, true).timeout
	# 激光开火（auto_aim 锁最近冻结靶）
	p._fire_cd = 0.0
	p.fire()
	# 火弹枪那只：手动点燃展示燃烧变红效果
	if e_fire.has_method("apply_burn"):
		e_fire.apply_burn(6.0, 2.5)
	await create_timer(0.22, true, false, true).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png("build/shot_weapons.png")
	print("SHOT_SAVED size=", img.get_size())
	quit()
