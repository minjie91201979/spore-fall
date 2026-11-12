extends SceneTree
# 视觉验证：结算页生涯统计 + 新成就行 / 标题页生涯摘要。
# 走隔离存档并直接调结算 UI，不改玩家真实的 save.cfg / career.cfg。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	var c = get_root().get_node_or_null("Career")
	if gs:
		gs.start_run()
	var spawner := current_scene.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)
	# 造一份「老玩家」生涯数据 + 本局刚解锁两个成就
	c.save_path = "user://career_shot.cfg"
	c.total_runs = 12
	c.total_kills = 1248
	c.total_playtime = 2840.0
	c.best_survival = 372.0
	c.best_combo = 34
	c.best_kills = 118
	c.unlocked = {"first_run": true, "kills_100": true, "kills_1000": true, "survive_300": true}
	c.run_new.clear()
	c.run_new.append("连杀狂人")
	c.run_new.append("高分猎手")
	# 本局战绩
	gs.score = 6200
	gs.survived_time = 254.0
	gs.kill_count = 96
	gs.max_combo = 26
	gs.weapon_level = 4
	var hud := current_scene.get_node_or_null("UILayer/HUD")
	if hud:
		hud.hide()
	var go := current_scene.get_node_or_null("UILayer/GameOver")
	go._on_game_over(6200, 254.0)
	await create_timer(1.25, true, false, true).timeout
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("build/shot_career_over.png")

	# 切到标题页看生涯摘要
	change_scene_to_file("res://scenes/ui/Title.tscn")
	for i in 40:
		await process_frame
	await create_timer(0.6, true, false, true).timeout
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("build/shot_career_title.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path))
	c.save_path = "user://career.cfg"
	print("SHOT_SAVED")
	quit()
