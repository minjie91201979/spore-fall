extends SceneTree
# 视觉验证：潜伏孢（远处半透明潜伏 / 近处已破土）与杂兵同框。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	var lurker = load("res://assets/data/enemy_lurker.tres")
	var walker = load("res://assets/data/enemy_walker.tres")
	# 玩家移到画面中心附近，镜头跟随
	p.global_position = Vector2.ZERO
	var angles := [0.6, 1.9, 3.1, 4.4, 5.5]
	for i in angles.size():
		var a: float = angles[i]
		var r: float = 240.0 if i < 2 else 430.0   # 近的破土追击，远的保持潜伏
		var e: Node2D = pool.acquire(current_scene) as Node2D
		e.configure(lurker)
		e.global_position = p.global_position + Vector2(cos(a), sin(a)) * r
	# 两只普通杂兵做对照
	for i in 2:
		var a: float = 2.4 + float(i) * 0.7
		var w: Node2D = pool.acquire(current_scene) as Node2D
		w.configure(walker)
		w.global_position = p.global_position + Vector2(cos(a), sin(a)) * 210.0
	await create_timer(1.4, true, false, true).timeout
	root.get_texture().get_image().save_png("build/shot_ambush.png")
	print("SHOT_SAVED")
	quit()
