extends Area2D
# 子弹（§11.4.3 远程）：直线飞行，命中敌人调用 take_damage，命中或超时回池。
# 池化（§11.9）：不再 queue_free，归还到 ObjectPool 复用；active=false 时完全停摆。
# §11.11：发射瞬间从 GameState.mods 读取弹速 / 射程 / 穿透，卡片加成对子弹是「发射时快照」，
# 已经在飞的子弹不会被追溯改写，避免暂停选卡那一刻弹道突然变速。
#
# 武器弹种（WeaponDB.bullet_kind，发射时快照进 opts）：
#   standard 普通孢针 / fire 燃烧弹（命中点燃 DoT）/ flame 火舌（短程半透明大弹、
#   可穿透、点燃）/ laser 激光（细长高热、无限穿透，串烧一整条线）
@export var base_speed: float = 620.0
@export var base_lifetime: float = 1.2
@export var damage: float = 12.0

# 各弹种外观：颜色与缩放（相对 bullet.png 原始 0.14 缩放）
const VISUALS: Dictionary = {
	"standard": {"color": Color(1.0, 0.96, 0.82), "scale": 1.0, "stretch": 1.0, "alpha": 1.0},
	"fire":     {"color": Color(1.0, 0.55, 0.18), "scale": 1.1, "stretch": 1.15, "alpha": 1.0},
	"flame":    {"color": Color(1.0, 0.42, 0.10), "scale": 2.4, "stretch": 1.3, "alpha": 0.75},
	"laser":    {"color": Color(0.35, 0.95, 1.0), "scale": 0.8, "stretch": 3.2, "alpha": 1.0},
}

var speed: float = 620.0
var lifetime: float = 1.2
var pierce_left: int = 0
var active: bool = true
var bullet_kind: String = "standard"
var burn_dps: float = 0.0
var burn_time: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _lifetime_left: float = 1.2
var _hit_ids: Array[int] = []
var _circle_shape: Shape2D   # 原始圆形碰撞体（普通弹种用），激光换长条后要换回来

@onready var _spr: Sprite2D = $Sprite2D
@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# 池 prefill 的停车场节点 active=false：不入计数组，组里只剩在飞的子弹
	if active:
		add_to_group("player_bullet")
	_circle_shape = _col.shape
	body_entered.connect(_on_body_entered)

# 由 Player 在生成时设定飞行方向与伤害（含重置，供池化复用）。
# opts（可选）：kind / speed_mult / life_mult / pierce / pierce_all /
#              burn_dps / burn_time —— 缺省全部退回普通孢针行为
func setup(direction: Vector2, dmg: float = 12.0, opts: Dictionary = {}) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()
	damage = dmg
	bullet_kind = String(opts.get("kind", "standard"))
	burn_dps = float(opts.get("burn_dps", 0.0))
	burn_time = float(opts.get("burn_time", 0.0))
	var mult: float = float(GameState.mods.bullet_speed) * float(opts.get("speed_mult", 1.0))
	speed = base_speed * mult
	# 弹速变快时射程同步变长，否则「疾风孢针」会变成负面卡（打得更快却更近）
	lifetime = base_lifetime * mult * float(opts.get("life_mult", 1.0))
	_lifetime_left = lifetime
	if bool(opts.get("pierce_all", false)):
		pierce_left = 999
	else:
		pierce_left = int(GameState.mods.pierce) + int(opts.get("pierce", 0))
	_apply_visual()
	_hit_ids.clear()
	# 从池里复用再入飞时回组（_release 时出过组）
	if not is_in_group("player_bullet"):
		add_to_group("player_bullet")

# 按弹种上色 / 拉伸：激光细长一条线，火舌大团半透明
func _apply_visual() -> void:
	var v: Dictionary = VISUALS.get(bullet_kind, VISUALS["standard"])
	var base: float = 0.14
	_spr.modulate = v["color"]
	_spr.modulate.a = v["alpha"]
	_spr.scale = Vector2(base * float(v["scale"]) * float(v["stretch"]), base * float(v["scale"]))
	# 激光弹速约 1300px/s ≈ 22px/物理帧，圆形单点碰撞会直接隧穿敌人。
	# 换成长条碰撞体（沿飞行方向 44px），半长 22px 覆盖单帧位移，保证命中。
	if bullet_kind == "laser":
		if not (_col.shape is RectangleShape2D):
			var rect := RectangleShape2D.new()
			rect.size = Vector2(44.0, 10.0)
			_col.shape = rect
	elif not (_col.shape is CircleShape2D):
		_col.shape = _circle_shape

func _physics_process(delta: float) -> void:
	if not active:
		return
	position += _direction * speed * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_release()

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.is_in_group("enemy"):
		var bid: int = body.get_instance_id()
		if _hit_ids.has(bid):
			return   # 穿透飞行中若物理体反复出入，不许同一只怪吃两次
		_hit_ids.append(bid)
		body.take_damage(damage)
		# 燃烧弹种：命中点燃（刷新制 DoT 在敌人侧结算）
		if burn_dps > 0.0 and body.has_method("apply_burn"):
			body.apply_burn(burn_dps, burn_time)
		if pierce_left > 0:
			pierce_left -= 1
			return   # 继续飞，串烧下一只；柱子仍然照常挡枪线
		_release()
	elif body.is_in_group("obstacle"):
		# 撞柱销毁：柱子可以当掩体卡枪线（走位博弈）
		Juice.add_trauma(0.04)
		Sfx.play("hit")
		_release()

# 归还池（物理回调内不能改树，走 deferred）
func _release() -> void:
	if not active:
		return
	active = false
	# 停摆的池节点退出计数组：组里只剩「在飞的子弹」
	if is_in_group("player_bullet"):
		remove_from_group("player_bullet")
	# 显式判 has_meta：get_meta(name, default) 在本版引擎里缺 key 仍会打 ERROR，
	# 探针/非池化路径直接实例化子弹时日志会被刷脏
	if has_meta("pool"):
		var pool: Node = get_meta("pool")
		if pool:
			pool.release.call_deferred(self)
			return
	queue_free()
