class_name EnemyBullet
extends Area2D
# 敌方弹幕（毒针 / 毒液 / 孢子）：直线飞行，命中玩家扣血（毒弹附带持续毒素），
# 撞障碍柱销毁（毒液会在原地留一小片毒云，柱后掩体对远程也成立）。
# 弹量低频（杂兵 2~3s 一发、Boss 技能 5.5s 一轮），不做对象池，命中/超时 queue_free。
# 纯 _draw 绘制外形：needle 细长毒针、venom/spore 脉动毒团 + 拖尾，不依赖贴图。

static var _alive_count: int = 0
const ALIVE_CAP := 90   # 同屏弹幕硬上限，防极端情况刷爆

var active: bool = true
var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 300.0
var _damage: float = 6.0
var _lifetime: float = 1.8
var _t: float = 0.0
var _kind: String = "venom"          # needle（细长针形）/ venom / spore（脉动毒团）
var _poison_dps: float = 0.0         # >0 命中附加持续毒素
var _poison_time: float = 2.0
var _leaves_cloud: bool = false      # 销毁时（撞柱/落地超时）留毒云
var _cloud_radius: float = 46.0
var _cloud_duration: float = 2.6
var _cloud_dps: float = 8.0
var _base_color: Color = Color(0.5, 0.85, 0.25)

func _ready() -> void:
	add_to_group("enemy_bullet")
	body_entered.connect(_on_body_entered)
	rotation = _dir.angle()
	_alive_count += 1

func _exit_tree() -> void:
	_alive_count -= 1

# 发射参数（Enemy 在前摇结束后调用）。opts 可选键见下。
func setup(dir: Vector2, dmg: float, speed: float, opts: Dictionary = {}) -> void:
	_dir = dir.normalized()
	rotation = _dir.angle()
	_damage = dmg
	_speed = speed
	_kind = opts.get("kind", "venom")
	_poison_dps = opts.get("poison_dps", 0.0)
	_poison_time = opts.get("poison_time", 2.0)
	_leaves_cloud = opts.get("leaves_cloud", false)
	_cloud_radius = opts.get("cloud_radius", 46.0)
	_cloud_duration = opts.get("cloud_duration", 2.6)
	_cloud_dps = opts.get("cloud_dps", 8.0)
	_base_color = opts.get("color", Color(0.5, 0.85, 0.25))
	_lifetime = opts.get("lifetime", 1.8)
	_t = 0.0
	active = true

func _physics_process(delta: float) -> void:
	if not active:
		return
	position += _dir * _speed * delta
	_t += delta
	queue_redraw()
	if _t >= _lifetime:
		# 落地超时：毒液弹在弹道终点留毒云（逼玩家别贴着掩体死角站）
		if _leaves_cloud:
			_leave_cloud()
		_expire()

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.is_in_group("player"):
		var p: Node = body
		if p.has_method("take_damage"):
			p.take_damage(_damage)
			if _poison_dps > 0.0 and p.has_method("apply_poison"):
				p.apply_poison(_poison_dps, _poison_time)
		_expire()
	elif body.is_in_group("obstacle"):
		# 撞柱：毒液在柱边留毒云，针直接碎掉
		if _leaves_cloud:
			_leave_cloud()
		Juice.add_trauma(0.03)
		_expire()

func _leave_cloud() -> void:
	if PoisonCloud._alive.size() >= PoisonCloud.CAP_HIGH:
		return   # 场上毒云已满，弹幕不再追加，守住性能
	PoisonCloud.spawn(get_tree().current_scene, global_position,
		_cloud_radius, _cloud_duration, _cloud_dps,
		Color(_base_color.r, _base_color.g, _base_color.b))

func _expire() -> void:
	if not active:
		return
	active = false
	queue_free()

func _draw() -> void:
	if _kind == "needle":
		# 细长毒针：亮绿主针 + 暗绿拖尾，朝飞行方向
		var tip: Vector2 = Vector2(16.0, 0.0)
		var tail: Vector2 = Vector2(-14.0, 0.0)
		draw_line(tail, tip, Color(_base_color.r, _base_color.g, _base_color.b, 0.35), 3.5)
		draw_line(Vector2(-6, 0), tip, Color(_base_color.r * 1.2, _base_color.g * 1.2, _base_color.b * 1.2), 4.0)
		draw_circle(tip, 3.0, Color(1.0, 1.0, 0.85, 0.9))
	else:
		# 毒团 / 孢子：脉动毒球 + 外圈暗晕，尺寸随时间轻微膨胀
		var r: float = 7.0 + 1.2 * sin(_t * 14.0) + _t * 2.0
		draw_circle(Vector2(-_dir * 5.0), r * 0.7, Color(_base_color.r, _base_color.g, _base_color.b, 0.28))
		draw_circle(Vector2.ZERO, r + 2.5, Color(_base_color.r * 0.6, _base_color.g * 0.6, _base_color.b * 0.6, 0.4))
		draw_circle(Vector2.ZERO, r, Color(_base_color.r, _base_color.g, _base_color.b, 0.85))
		draw_circle(Vector2(-2.0, -2.0), r * 0.4, Color(1.0, 1.0, 1.0, 0.5))
