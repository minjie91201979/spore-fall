extends SceneTree
# 视觉验证：M4 新变种 —— 毒雾孢/分裂孢贴图、死亡毒雾区、迷你分裂子体同框。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var spawner := current_scene.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	p.global_position = Vector2(0, 220)
	var miasma = load("res://assets/data/enemy_miasma.tres")
	var splitter = load("res://assets/data/enemy_splitter.tres")

	# 两只活的展示贴图
	for item in [[miasma, Vector2(-300, -70)], [splitter, Vector2(300, -70)]]:
		var e: Node2D = pool.acquire(current_scene) as Node2D
		e.configure(item[0])
		e.global_position = item[1]
	# 一只毒雾孢死亡留雾、一只分裂孢死亡裂子体
	var m: Node2D = pool.acquire(current_scene) as Node2D
	m.configure(miasma)
	m.global_position = Vector2(-110, 20)
	m.take_damage(9999.0)
	var s: Node2D = pool.acquire(current_scene) as Node2D
	s.configure(splitter)
	s.global_position = Vector2(150, 20)
	s.take_damage(9999.0)

	await create_timer(0.8, true, false, true).timeout
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("build/shot_variants.png")
	print("SHOT_SAVED")
	quit()
