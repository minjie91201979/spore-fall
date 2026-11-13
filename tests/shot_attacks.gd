extends SceneTree
# 视觉验证探针（§11.12/§11.13）：毒针孢 + 酸液孢 + Boss 弹幕环同框，截屏 build/shot_attacks.png
# 用法（必须带窗口，不能 --headless）：
#   Godot.exe --path . --script tests/shot_attacks.gd

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var spawner = current_scene.get_node_or_null("Spawner")
	var p = get_first_node_in_group("player")
	if spawner == null or p == null:
		print("SETUP_FAILED")
		quit()
		return
	var pool = get_first_node_in_group("enemy_pool")

	# 毒针孢：右侧射程带内，立即进入蓄射
	var spitter: Node2D = pool.acquire(current_scene)
	spitter.configure(load("res://assets/data/enemy_spitter.tres"))
	spitter.global_position = p.global_position + Vector2(240.0, -60.0)
	spitter._ranged_cd = 0.0

	# 酸液孢：左下射程带内，立即进入蓄射
	var sprayer: Node2D = pool.acquire(current_scene)
	sprayer.configure(load("res://assets/data/enemy_sprayer.tres"))
	sprayer.global_position = p.global_position + Vector2(-220.0, 90.0)
	sprayer._ranged_cd = 0.0

	# Boss：右上近处，强制弹幕环出招（紫环毒团可视化）
	var boss = spawner.spawn_boss()
	if boss:
		boss.global_position = p.global_position + Vector2(150.0, -140.0)
		boss._skill_pending = 0
		boss._charge_state = 3
		boss._charge_t = 0.05
	if gs:
		gs.score = 8600
		gs.combo = 9
	# 等弹幕飞到半途 + 毒针/毒液在空中，画面信息量最大
	await create_timer(0.55, true, false, true).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png("build/shot_attacks.png")
	print("SHOT_SAVED size=", img.get_size())
	quit()
