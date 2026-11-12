extends Area2D
# 子弹（§11.4.3 远程）：直线飞行，命中敌人调用 take_damage，命中或超时回池。
# 池化（§11.9）：不再 queue_free，归还到 ObjectPool 复用；active=false 时完全停摆。
# §11.11：发射瞬间从 GameState.mods 读取弹速 / 射程 / 穿透，卡片加成对子弹是「发射时快照」，
# 已经在飞的子弹不会被追溯改写，避免暂停选卡那一刻弹道突然变速。
@export var base_speed: float = 620.0
@export var base_lifetime: float = 1.2
@export var damage: float = 12.0

var speed: float = 620.0
var lifetime: float = 1.2
var pierce_left: int = 0
var active: bool = true
var _direction: Vector2 = Vector2.RIGHT
var _lifetime_left: float = 1.2
var _hit_ids: Array[int] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = _direction.angle()

# 由 Player 在生成时设定飞行方向与伤害（含重置，供池化复用）
func setup(direction: Vector2, dmg: float = 12.0) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()
	damage = dmg
	var mult: float = float(GameState.mods.bullet_speed)
	speed = base_speed * mult
	# 弹速变快时射程同步变长，否则「疾风孢针」会变成负面卡（打得更快却更近）
	lifetime = base_lifetime * mult
	_lifetime_left = lifetime
	pierce_left = int(GameState.mods.pierce)
	_hit_ids.clear()

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
	# 显式判 has_meta：get_meta(name, default) 在本版引擎里缺 key 仍会打 ERROR，
	# 探针/非池化路径直接实例化子弹时日志会被刷脏
	if has_meta("pool"):
		var pool: Node = get_meta("pool")
		if pool:
			pool.release.call_deferred(self)
			return
	queue_free()
