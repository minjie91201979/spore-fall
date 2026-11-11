extends CanvasLayer
# 移动端虚拟摇杆 + 攻击按钮（§双端操控）。
# 左半屏按下拖动 = 摇杆，写入 TouchInput.move_vector；
# 右下 FIRE 按钮按住 = 持续调用玩家的 fire()。

@onready var joy_base: Sprite2D = $Joystick/Base
@onready var joy_knob: Sprite2D = $Joystick/Knob
@onready var attack_btn: Button = $AttackButton

const JOY_RADIUS: float = 70.0
const FIRE_INTERVAL: float = 0.22

var _joy_active: bool = false
var _joy_id: int = -2            # 触摸指针 index；鼠标用 -1
var _joy_origin: Vector2 = Vector2.ZERO
var _attack_held: bool = false
var _fire_timer: float = 0.0

func _ready() -> void:
	joy_base.visible = false
	joy_knob.visible = false
	attack_btn.button_down.connect(_on_attack_down)
	attack_btn.button_up.connect(_on_attack_up)

func _on_attack_down() -> void:
	_attack_held = true
	_fire_timer = 0.0
	_fire()

func _on_attack_up() -> void:
	_attack_held = false

func _fire() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("fire"):
		p.fire()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		var is_touch: bool = event is InputEventScreenTouch
		var id: int = -1
		if is_touch:
			id = event.index
		var pos: Vector2 = event.position
		if event.pressed:
			if not _joy_active and pos.x < get_viewport().size.x * 0.5:
				_joy_active = true
				_joy_id = id
				_joy_origin = pos
				joy_base.visible = true
				joy_knob.visible = true
				joy_base.global_position = pos
				joy_knob.global_position = pos
				TouchInput.move_vector = Vector2.ZERO
		else:
			if _joy_active and _joy_id == id:
				_joy_active = false
				_joy_id = -2
				joy_base.visible = false
				joy_knob.visible = false
				TouchInput.move_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and _joy_active and event.index == _joy_id:
		_update_joy(event.position)
	elif event is InputEventMouseMotion and _joy_active and _joy_id == -1:
		_update_joy(event.position)

func _update_joy(pos: Vector2) -> void:
	var delta: Vector2 = pos - _joy_origin
	if delta.length() > JOY_RADIUS:
		delta = delta.normalized() * JOY_RADIUS
	joy_knob.global_position = _joy_origin + delta
	TouchInput.move_vector = delta / JOY_RADIUS

func _process(delta: float) -> void:
	if _attack_held:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire()
			_fire_timer = FIRE_INTERVAL
