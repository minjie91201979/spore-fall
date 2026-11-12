extends SceneTree
# 视觉验证：被打爆演出两阶段 —— 阶段A 闪白膨胀+冲击环 / 阶段B 贴图碎片四散。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	p.global_position = Vector2(-260, 220)
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
		e.global_position = Vector2(-260 + i * 140, -30)
		e.take_damage(9999.0)
	await create_timer(0.05, true, false, true).timeout    # 阶段A：闪白膨胀
	for i in 2:
		await process_frame                                  # 确保最新帧已提交再截
	root.get_texture().get_image().save_png("build/shot_burst_pop.png")
	await create_timer(0.18, true, false, true).timeout   # 阶段B：碎片四散
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("build/shot_burst_shards.png")
	var db = load("res://scripts/fx/DeathBurst.gd")
	print("SHOT_SAVED alive=%d" % db._alive.size())
	quit()
