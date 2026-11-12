extends SceneTree
# 探针：虚拟摇杆手感参数与输入桥（§11.6 双端操控）。
# 直接向 TouchControls._unhandled_input 注入事件，不依赖真实触摸设备。

const VIEW_W := 1152.0
const VIEW_H := 648.0

var tc: Node
var bus: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 15:
		await process_frame
	bus = get_root().get_node_or_null("TouchInput")
	tc = current_scene.get_node_or_null("TouchControls")
	print("TC_FOUND=", tc != null)
	if tc == null or bus == null:
		quit()
		return
	var base: Sprite2D = tc.get_node("Joystick/Base")

	var origin := Vector2(VIEW_W * 0.22, VIEW_H * 0.72)
	_send_touch(0, origin, true)
	print("JOY_VISIBLE_ON_PRESS=", base.visible)

	# 死区内（6px / 72px = 0.083 < 0.18）→ 必须完全静止
	_send_drag(0, origin + Vector2(6.0, 0.0))
	print("DEADZONE_LEN=", snappedf(bus.move_vector.length(), 0.001))

	# 半程 36px → 原始 0.5，死区重映射后应约 0.39
	_send_drag(0, origin + Vector2(36.0, 0.0))
	print("HALF_LEN=", snappedf(bus.move_vector.length(), 0.01), " X=", snappedf(bus.move_vector.x, 0.01))

	# 超程 200px → 夹到半径，长度为 1
	_send_drag(0, origin + Vector2(200.0, 0.0))
	print("FULL_LEN=", snappedf(bus.move_vector.length(), 0.01))

	# 向上拉 → 方向应为 -Y
	_send_drag(0, origin + Vector2(0.0, -200.0))
	print("UP_DIR_Y=", snappedf(bus.move_vector.y, 0.01))

	_send_touch(0, origin, false)
	print("RELEASE_LEN=", snappedf(bus.move_vector.length(), 0.001))
	await create_timer(0.25, true, false, true).timeout
	print("JOY_HIDDEN_AFTER_RELEASE=", not base.visible)

	# 右半屏按下不应起摇杆（留给 FIRE）
	_send_touch(1, Vector2(VIEW_W * 0.8, VIEW_H * 0.5), true)
	print("RIGHT_HALF_NO_JOY=", not base.visible)
	_send_touch(1, Vector2(VIEW_W * 0.8, VIEW_H * 0.5), false)

	# 攻击键按住/松开状态
	var btn: Button = tc.get_node("AttackButton")
	btn.button_down.emit()
	print("ATTACK_HELD=", tc._attack_held)
	btn.button_up.emit()
	print("ATTACK_RELEASED=", not tc._attack_held)

	# 重开一局：Autoload 上的残留移动量必须被清掉（否则复活后自动漂移）
	bus.move_vector = Vector2(0.9, 0.0)
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 10:
		await process_frame
	print("RESET_ON_RELOAD=", snappedf(bus.move_vector.length(), 0.001))
	print("OK")
	quit()

func _send_touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	tc._unhandled_input(e)

func _send_drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	tc._unhandled_input(e)
