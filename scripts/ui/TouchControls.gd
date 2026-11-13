extends CanvasLayer
# 移动端虚拟摇杆 + 攻击按钮（§11.6 双端操控）。
#
# 手感要点（都是移动端的常识参数，不是拍脑袋）：
#   1) 死区 0.18：手指微抖不会让角色蠕动；死区外的行程重映射到 0..1，保证小摇杆也有全量程。
#   2) 按下即从 0.82 弹到 1.0（EASE_OUT + BACK）：触摸有「抓住一个实体」的回执。
#   3) 旋钮随力度放大 10%、基座随力度提亮：推到底有可读的上限，不用看数值。
#   4) 起摇杆不要求点中基座：左半屏任意点按下就地生成，拇指不用瞄准。
#   5) 攻击键 keep_pressed_outside：拇指滑出按钮不误停火。

const JOY_RADIUS := 72.0     # 旋钮最大位移（屏幕像素）
const DEAD_ZONE := 0.18      # 死区比例
const FADE_OUT := 0.12

@onready var joy_base: Sprite2D = $Joystick/Base
@onready var joy_knob: Sprite2D = $Joystick/Knob
@onready var attack_btn: Button = $AttackButton
@onready var interact_btn: Button = $InteractButton

var _joy_active: bool = false
var _joy_id: int = -2            # 触摸指针 index；鼠标用 -1
var _joy_origin: Vector2 = Vector2.ZERO
var _attack_held: bool = false

func _ready() -> void:
	add_to_group("touch_controls")
	# 场景重载（死亡重开）时清掉上一局按住的移动量：
	# TouchInput 是 Autoload，不会随场景销毁；若玩家死时正按着摇杆，
	# 松手事件会丢给已销毁的节点，不清就会「复活后自己往一个方向走」。
	TouchInput.move_vector = Vector2.ZERO
	joy_base.visible = false
	joy_knob.visible = false
	attack_btn.button_down.connect(_on_attack_down)
	attack_btn.button_up.connect(_on_attack_up)
	interact_btn.visible = false
	interact_btn.pressed.connect(_on_interact)

# 升级弹窗会暂停整棵树，暂停期间手指松开的事件可能丢给已停处理的节点。
# 关闭弹窗前由 UpgradeUI 调这里统一复位，否则恢复瞬间角色会「自己走」或 FIRE 自动连发。
func reset_input() -> void:
	_attack_held = false
	_joy_active = false
	_joy_id = -2
	TouchInput.move_vector = Vector2.ZERO
	attack_btn.scale = Vector2.ONE
	joy_base.visible = false
	joy_knob.visible = false

# ---------------- 开火 ----------------
func _on_attack_down() -> void:
	_attack_held = true
	attack_btn.scale = Vector2.ONE * 0.94
	_fire()

func _on_attack_up() -> void:
	_attack_held = false
	attack_btn.scale = Vector2.ONE

func _fire() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("fire"):
		p.fire()

func _on_interact() -> void:
	var director := get_tree().get_first_node_in_group("story_director")
	if director and director.has_method("try_interact"):
		director.try_interact()

func _process(_delta: float) -> void:
	# 射速由 Player._attack 的统一冷却控制，这里每帧请求即可
	if _attack_held:
		_fire()
	# 生存局没有剧情导演，互动键保持隐藏，不占 FIRE 旁边的位置
	var director := get_tree().get_first_node_in_group("story_director")
	var show_interact := director != null and bool(director.get("interact_available"))
	interact_btn.visible = show_interact

# ---------------- 摇杆 ----------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		var is_touch: bool = event is InputEventScreenTouch
		var id: int = event.index if is_touch else -1
		var pos: Vector2 = event.position
		if event.pressed:
			if not _joy_active and pos.x < get_viewport().get_visible_rect().size.x * 0.5:
				_begin_joy(pos, id)
		elif _joy_active and _joy_id == id:
			_end_joy()
	elif event is InputEventScreenDrag and _joy_active and event.index == _joy_id:
		_update_joy(event.position)
	elif event is InputEventMouseMotion and _joy_active and _joy_id == -1:
		_update_joy(event.position)

func _begin_joy(pos: Vector2, id: int) -> void:
	_joy_active = true
	_joy_id = id
	_joy_origin = pos
	joy_base.global_position = pos
	joy_knob.global_position = pos
	joy_base.visible = true
	joy_knob.visible = true
	joy_base.modulate.a = 0.9
	joy_knob.modulate.a = 1.0
	joy_base.scale = Vector2.ONE * 0.82
	joy_knob.scale = Vector2.ONE
	TouchInput.move_vector = Vector2.ZERO
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(joy_base, "scale", Vector2.ONE, 0.16)

func _end_joy() -> void:
	_joy_active = false
	_joy_id = -2
	TouchInput.move_vector = Vector2.ZERO
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(joy_base, "scale", Vector2.ONE * 0.86, FADE_OUT)
	tw.tween_property(joy_base, "modulate:a", 0.0, FADE_OUT)
	tw.tween_property(joy_knob, "modulate:a", 0.0, FADE_OUT)
	await get_tree().create_timer(FADE_OUT + 0.02, true, false, true).timeout
	if not _joy_active:   # 期间又按下了就别收
		joy_base.visible = false
		joy_knob.visible = false

func _update_joy(pos: Vector2) -> void:
	var delta: Vector2 = pos - _joy_origin
	var len: float = delta.length()
	if len > JOY_RADIUS:
		delta = delta.normalized() * JOY_RADIUS
		len = JOY_RADIUS
	var raw: float = len / JOY_RADIUS
	var strength: float = 0.0
	if raw > DEAD_ZONE:
		strength = (raw - DEAD_ZONE) / (1.0 - DEAD_ZONE)
	joy_knob.global_position = _joy_origin + delta
	joy_knob.scale = Vector2.ONE * (1.0 + 0.10 * strength)
	joy_base.modulate.a = 0.75 + 0.25 * strength
	TouchInput.move_vector = delta.normalized() * strength if len > 0.001 else Vector2.ZERO
