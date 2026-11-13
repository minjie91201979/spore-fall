extends SceneTree
# 探针：标题双入口。生存仍经准备页进入 Arena，最高分照旧落盘。

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
	var story_btn: Button = title.get_node("Center/StoryButton")
	var survival_btn: Button = title.get_node("Center/SurvivalButton")
	var quality_btn: Button = title.get_node("Center/QualityButton")
	var hint: Label = title.get_node("Center/SurvivalHint")
	print("STORY_TEXT=", story_btn.text)
	print("SURVIVAL_TEXT=", survival_btn.text)
	print("SURVIVAL_ENABLED=", not survival_btn.disabled)
	print("HINT_HIDDEN_EMPTY=", not hint.visible)

	q.set_level(2)
	print("QUALITY_TEXT_HIGH=", quality_btn.text)
	q.set_level(0)
	print("QUALITY_TEXT_LOW=", quality_btn.text, " level=", q.level)
	q.set_level(2)

	var orig_best: int = gs.best_score
	gs.best_score = 98765
	title._refresh_summaries()
	print("BEST_TEXT=", hint.text, " visible=", hint.visible)
	gs.best_score = orig_best
	title._refresh_summaries()

	survival_btn.pressed.emit()
	await create_timer(0.6, true, false, true).timeout
	print("AFTER_SURVIVAL_SCENE=", current_scene.name if current_scene else "NONE")
	var enter: Button = current_scene.get_node("Center/EnterButton")
	print("ENTER_TEXT=", enter.text)
	enter.pressed.emit()
	await create_timer(0.8, true, false, true).timeout
	print("AFTER_START_SCENE=", current_scene.name if current_scene else "NONE")
	print("IS_RUNNING=", gs.is_running)
	print("RUN_MODE=", gs.run_mode)
	var player = get_first_node_in_group("player")
	print("PLAYER_PRESENT=", player != null)
	print("INFINITE_AMMO=", player.infinite_ammo if player else false)

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
