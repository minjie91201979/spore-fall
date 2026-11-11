extends Area2D
# 子弹（§11.4.3 远程）：直线飞行，命中敌人调用 take_damage，命中或超时回池。
# 池化（§11.9）：不再 queue_free，归还到 ObjectPool 复用；active=false 时完全停摆。
@export var speed: float = 620.0
@export var damage: float = 12.0
@export var lifetime: float = 1.2

var active: bool = true
var _direction: Vector2 = Vector2.RIGHT
var _lifetime_left: float = 1.2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = _direction.angle()

# 由 Player 在生成时设定飞行方向与伤害（含重置，供池化复用）
func setup(direction: Vector2, dmg: float = 12.0) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()
	_lifetime_left = lifetime
	damage = dmg

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
		body.take_damage(damage)
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
	var pool: Node = get_meta("pool", null)
	if pool:
		pool.release.call_deferred(self)
	else:
		queue_free()
