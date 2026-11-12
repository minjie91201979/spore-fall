extends SceneTree
# 视觉验证：美术统一重绘 —— 5 变种 + Boss + 玩家全家福同框。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	p.global_position = Vector2(-330, 260)
	# 一字排开：walker / runner / brute / lurker / boss
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
		e.global_position = Vector2(-330 + i * 165, -60)
		await create_timer(0.3, true, false, true).timeout
	# 拉开一点时间让伏击体进入潜伏态（贴近玩家会破土，这里距离足够远）
	await create_timer(1.2, true, false, true).timeout
	root.get_texture().get_image().save_png("build/shot_tex.png")
	print("SHOT_SAVED")
	quit()
