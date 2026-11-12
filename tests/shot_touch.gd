extends SceneTree
# 视觉验证：按下左侧摇杆 + 推到接近满程，截屏看摇杆/开火键的实际观感。

var tc: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	tc = current_scene.get_node_or_null("TouchControls")
	if tc == null:
		print("NO_TOUCH")
		quit()
		return
	var origin := Vector2(250.0, 470.0)
	_touch(0, origin, true)
	await create_timer(0.2, true, false, true).timeout
	_drag(0, origin + Vector2(58.0, -26.0))
	await create_timer(0.35, true, false, true).timeout
	root.get_texture().get_image().save_png("build/shot_touch.png")
	print("SHOT_SAVED")
	quit()

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	tc._unhandled_input(e)

func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	tc._unhandled_input(e)
