class_name PoisonCloud
extends Node2D
# 毒雾孢死亡残留（§11.5 M4）：原地留一片毒绿雾区，按 dps 持续伤害，逼玩家离开。
# 单 CanvasItem 纯 _draw（雾团脉动 + 边界环），每 0.5s 一次距离判定即可，无 Area2D 开销。
# 用法：PoisonCloud.spawn(parent, pos, radius, duration, dps, color)

const TICK := 0.5           # 伤害结算间隔
const FADE_TIME := 0.9      # 末尾淡出
const CAP_HIGH := 12
const CAP_LOW := 6

var _radius: float = 78.0
var _duration: float = 4.0
var _dps: float = 10.0
var _color: Color = Color(0.45, 0.72, 0.12)
var _t: float = 0.0
var _tick_t: float = 0.0
var _puffs: Array = []      # [Vector2 基准偏移, float 半径, float 相位]
var _player: Node2D

static var _alive: Array[PoisonCloud] = []

static func spawn(parent: Node, pos: Vector2, radius: float, duration: float,
		dps: float, color: Color) -> PoisonCloud:
	var c: PoisonCloud = PoisonCloud.new()
	c._radius = radius
	c._duration = duration
	c._dps = dps
	c._color = color
	c.position = pos
	c.z_index = 1
	c.z_as_relative = false
	parent.add_child(c)
	_alive.push_back(c)
	var q: Node = parent.get_tree().root.get_node_or_null("Quality")
	var cap: int = CAP_LOW if q != null and int(q.get("level")) == 0 else CAP_HIGH
	while _alive.size() > cap:
		var oldest: PoisonCloud = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	return c

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	# 主雾团 + 5 个漂浮小雾团，缓慢脉动做出「气体在翻滚」的感觉
	_puffs.push_back([Vector2.ZERO, _radius * 0.62, 0.0])
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + randf() * 0.4
		_puffs.push_back([Vector2(cos(a), sin(a)) * _radius * 0.48,
			_radius * randf_range(0.24, 0.38), randf() * TAU])

func _process(delta: float) -> void:
	# 还原成真实秒：受击 hitstop / 死亡慢动作会把 delta 压小，毒雾不该因此赖着不走
	var real_delta: float = delta / maxf(Engine.time_scale, 0.05)
	_t += real_delta
	if _t >= _duration + FADE_TIME:
		_expire()
		return
	# 伤害结算：玩家在半径内每 TICK 秒扣一次（直接复用 take_damage 的受击反馈）
	_tick_t += real_delta
	if _tick_t >= TICK and _t < _duration:
		_tick_t -= TICK
		if is_instance_valid(_player) and global_position.distance_to(_player.global_position) < _radius \
				and float(_player.get("health")) > 0.0:
			_player.take_damage(_dps * TICK)
	# 末尾整体淡出（modulate 会乘到所有 draw 命令上）
	var fade_start: float = _duration
	modulate.a = clampf(1.0 - (_t - fade_start) / FADE_TIME, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	RenderingServer.canvas_item_clear(get_canvas_item())
	var pulse: float = 1.0 + 0.06 * sin(_t * 4.0)
	for p in _puffs:
		var drift: Vector2 = Vector2(sin(_t * 1.4 + p[2]), cos(_t * 1.1 + p[2])) * 4.0
		draw_circle(p[0] * pulse + drift, p[1] * pulse,
			Color(_color.r, _color.g, _color.b, 0.22 * modulate.a))
	# 边界细环：玩家一眼读出「毒雾范围」
	draw_arc(Vector2.ZERO, _radius * pulse, 0.0, TAU, 40,
		Color(_color.r * 1.3, _color.g * 1.3, _color.b * 1.3, 0.55 * modulate.a), 2.0)

func _expire() -> void:
	_alive.erase(self)
	queue_free()

func _exit_tree() -> void:
	_alive.erase(self)
