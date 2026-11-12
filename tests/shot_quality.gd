extends SceneTree
# 视觉验证：同一构图下截 高档 / 低档 两张图，检查描边 pass 与光影差异。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	var quality = get_root().get_node_or_null("Quality")
	if gs:
		gs.start_run()
	if quality:
		quality.set_level(2)

	var p = get_first_node_in_group("player")
	var enemy_scene: PackedScene = load("res://scenes/world/Enemy.tscn")
	var walker = load("res://assets/data/enemy_walker.tres")
	var brute = load("res://assets/data/enemy_brute.tres")
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		var e = enemy_scene.instantiate()
		e.position = p.global_position + Vector2(cos(a), sin(a)) * 92.0
		current_scene.add_child(e)
		e.configure(brute if i % 3 == 0 else walker)

	await create_timer(0.6, true, false, true).timeout
	root.get_texture().get_image().save_png("build/shot_quality_high.png")

	if quality:
		quality.set_level(0)
	await create_timer(0.4, true, false, true).timeout
	root.get_texture().get_image().save_png("build/shot_quality_low.png")

	if quality:
		quality.set_level(2)   # 还原，别把低档留给下次启动
	print("SHOTS_SAVED")
	quit()
