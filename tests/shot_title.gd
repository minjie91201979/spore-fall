extends SceneTree
# 视觉验证：标题界面截屏。

func _initialize() -> void:
	change_scene_to_file("res://scenes/ui/Title.tscn")
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.best_score = 12480
	for i in 70:
		await process_frame
	var title = current_scene
	if title and title.has_method("_refresh_best"):
		title._refresh_best()
	await create_timer(0.5, true, false, true).timeout
	root.get_texture().get_image().save_png("build/shot_title.png")
	print("SHOT_SAVED")
	quit()
