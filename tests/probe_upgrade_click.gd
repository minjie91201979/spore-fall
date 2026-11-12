extends SceneTree
# 验证：暂停状态下卡片仍能收到「真实」鼠标/触屏点击。
# 手机端没有键盘 1/2/3 兜底，这是唯一选卡路径，必须走 OS 输入队列而不是 emit_signal。
#
# ⚠️ 本探针必须「真渲染」跑：$GODOT --path . --script tests/probe_upgrade_click.gd
#    --headless 用 dummy 字体度量，VBoxContainer 会被撑高，卡片 get_global_rect()
#    算出来落在 y≈617（真渲染是 y≈365），点击自然打空——那是测试环境差异，不是 UI bug。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	gs.save_path = "user://save_upgrade_click.cfg"
	gs.start_run()
	var spawner := current_scene.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)
	var ui: Control = current_scene.get_node_or_null("UILayer/UpgradeUI")
	var applied: Array = []
	gs.upgrade_applied.connect(func(id): applied.append(id))

	gs.crystals = gs.crystals_for_next() - 1
	gs.add_crystal()
	await create_timer(0.2, true, false, true).timeout
	var opened: bool = ui.visible and paused

	var card: Button = ui.get_node("Center/Cards/Card1")
	var pos: Vector2 = card.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	Input.parse_input_event(down)
	for i in 3:
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	Input.parse_input_event(up)
	for i in 5:
		await process_frame

	var clicked: bool = applied.size() == 1 and not ui.visible and not paused
	print("CLICK opened=%s applied=%d closed=%s card_center=%s" % [
		opened, applied.size(), not ui.visible, str(pos)])
	print("PROBE_RESULT=", "PASS" if opened and clicked else "FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.save_path = "user://save.cfg"
	quit(0 if opened and clicked else 1)
