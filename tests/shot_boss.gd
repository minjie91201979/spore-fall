extends SceneTree
# 视觉验证探针：召唤 1 只 Boss + 几只杂兵，截屏到 build/shot_boss.png
# 用法（必须带窗口，不能 --headless）：
#   Godot_console.exe --path . --script tests/shot_boss.gd

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
	for i in 8:
		spawner._spawn_one()
	var boss = spawner.spawn_boss()
	if boss:
		boss.global_position = p.global_position + Vector2(110.0, -70.0)
	if gs:
		gs.score = 12480
		gs.combo = 17
	await create_timer(1.0, true, false, true).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png("build/shot_boss.png")
	print("SHOT_SAVED size=", img.get_size())
	quit()
