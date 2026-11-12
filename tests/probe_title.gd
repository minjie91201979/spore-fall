extends SceneTree
# 探针：标题界面与开局流转。
# 覆盖 场景加载 / 画质按钮 / 最高分展示 / 开始游戏切场景 / 最高分落盘。

var gs: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/ui/Title.tscn")
	for i in 15:
		await process_frame
	gs = get_root().get_node_or_null("GameState")
	var q = get_root().get_node_or_null("Quality")
	var title = current_scene
	print("TITLE_SCENE=", title.name if title else "NONE")
	if title == null or gs == null or q == null:
		quit()
		return
	var start_btn: Button = title.get_node("Center/StartButton")
	var quality_btn: Button = title.get_node("Center/QualityButton")
	var best: Label = title.get_node("Center/BestLabel")
	print("START_TEXT=", start_btn.text)
	print("START_ENABLED=", not start_btn.disabled)
	print("BEST_VISIBLE_EMPTY=", best.visible)

	# 画质按钮：切档后文案跟着变，且 Quality.level 真的改了
	q.set_level(2)
	print("QUALITY_TEXT_HIGH=", quality_btn.text)
	q.set_level(0)
	print("QUALITY_TEXT_LOW=", quality_btn.text, " level=", q.level)
	q.set_level(2)

	# 最高分展示
	var orig_best: int = gs.best_score
	gs.best_score = 98765
	title._refresh_best()
	print("BEST_TEXT=", best.text, " visible=", best.visible)
	gs.best_score = orig_best

	# 开始游戏 → 载入 Arena 并真正进入局内
	start_btn.pressed.emit()
	await create_timer(0.8, true, false, true).timeout
	print("AFTER_START_SCENE=", current_scene.name if current_scene else "NONE")
	print("IS_RUNNING=", gs.is_running)
	var player = get_first_node_in_group("player")
	print("PLAYER_PRESENT=", player != null)

	# 最高分落盘（end_run 内写 user://save.cfg），测完还原，别污染玩家存档
	gs.score = 4321
	gs.survived_time = 12.0
	gs.end_run()
	await process_frame
	print("BEST_SAVED=", gs.best_score)
	print("SAVE_EXISTS=", FileAccess.file_exists("user://save.cfg"))
	gs.best_score = orig_best
	gs._save_best()
	print("OK")
	quit()
