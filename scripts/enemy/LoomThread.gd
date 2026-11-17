extends Node2D
# §Wave3 织理者的线（设计文档 §四）：P2 起生效的动态地形。
#   - Boss 进 P2 spawn 2 条交叉线（对角线方向），P3 再补 2 条
#   - 每条 life=8s，两端以 shrink_rate=12px/s 同步向中点收缩
#   - 缩到最短 60px 后消失，消失点 spawn 1 颗伪晶体（惩罚未撤离的玩家）
# 视觉用 Line2D，自身在 _ready 组装；不占物理层，穿线只给「擦过」反馈，避免卡死走位。
# Boss 死亡由 Enemy._clear_loom_effects 统一 queue_free。

const LIFE: float = 8.0
const SHRINK_RATE: float = 12.0
const MIN_LEN: float = 60.0

var _start: Vector2
var _end: Vector2
var _life: float = LIFE
var _line: Line2D

func configure(a: Vector2, b: Vector2) -> void:
	_start = a
	_end = b

func _ready() -> void:
	add_to_group("loom_thread")
	_line = Line2D.new()
	_line.width = 5.0
	# Godot 4.7 里 Line2D.LINE_CAP_* 常量赋值会触发类型报错（tscn 用整数 2），
	# 直接跳过——默认尖角对一条收缩的直线视觉无差别，且杜绝脚本错误。
	_line.default_color = Color(0.95, 0.55, 0.2, 0.85)
	_line.add_point(_start)
	_line.add_point(_end)
	add_child(_line)

func _process(delta: float) -> void:
	_life -= delta
	# 两端向中点收缩：每帧各内缩 SHRINK_RATE*delta
	var mid: Vector2 = (_start + _end) * 0.5
	var full: Vector2 = _end - _start
	var cur_len: float = full.length()
	if cur_len <= 1.0:
		_vanish(); return
	var step: float = minf(SHRINK_RATE * delta, maxf(0.0, (cur_len - MIN_LEN) * 0.5))
	var dir: Vector2 = full.normalized()
	_start += dir * step
	_end -= dir * step
	_line.points = PackedVector2Array([_start, _end])
	# 越接近消失越亮（收缩的紧迫感）
	var urgency: float = 1.0 - clampf(_life / LIFE, 0.0, 1.0)
	_line.default_color = Color(1.0, 0.55 - urgency * 0.3, 0.2, 0.7 + urgency * 0.3)
	if (_end - _start).length() <= MIN_LEN + 1.0 or _life <= 0.0:
		_vanish()

func _vanish() -> void:
	_spawn_false_crystal((_start + _end) * 0.5)
	queue_free()

func _spawn_false_crystal(pos: Vector2) -> void:
	var pk: Node2D = preload("res://scenes/world/Pickup.tscn").instantiate()
	pk.kind = "false"
	pk.fake_hp_penalty = 26.0
	pk.position = pos
	get_tree().current_scene.add_child(pk)
