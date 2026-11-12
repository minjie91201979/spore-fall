extends SceneTree
# 视觉验证：死亡血水残迹 —— 每个变种一只，玩家当场击杀后同框看各色血渍。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	p.global_position = Vector2(-320, 240)
	var defs := [
		"res://assets/data/enemy_walker.tres",
		"res://assets/data/enemy_runner.tres",
		"res://assets/data/enemy_brute.tres",
		"res://assets/data/enemy_lurker.tres",
		"res://assets/data/enemy_boss.tres",
	]
	for i in defs.size():
		var e: Node2D = pool.acquire(current_scene) as Node2D
		e.configure(load(defs[i]))
		e.global_position = Vector2(-320 + i * 160, -40)
		e.take_damage(9999.0)   # 当场击杀 → 留血渍
	await create_timer(0.5, true, false, true).timeout   # 等血渍溅开摊平
	root.get_texture().get_image().save_png("build/shot_blood.png")
	print("SHOT_SAVED")
	quit()
