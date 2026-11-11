extends CharacterBody2D
# 自动索敌 + 接触掉血 + 受击 + 死亡回收（§11.4.2 / §11.4.3）。
# 用 NavigationAgent2D 走避障路径，绕开竞技场中央的障碍柱；
# 目标实时设为玩家位置，由导航网格算出绕障路点。
# 池化（§11.9）：死亡不再 queue_free，归还 ObjectPool 复用；粒子改为「复制一份留在原地爆」，
# 本体带着粒子节点回池，保证每次死亡都有击杀爆裂。

@export var stats: EnemyStats

const PICKUP_SCENE := preload("res://scenes/world/Pickup.tscn")

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var particles: GPUParticles2D = $KillParticles

var active: bool = true
var health: float = 40.0
var _player: Node2D
var _contact_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	if stats:
		health = stats.max_health
	_player = get_tree().get_first_node_in_group("player")
	# 延后一帧等导航地图同步完成（Godot 4.x 推荐），再配置 agent 参数
	await get_tree().physics_frame
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0

# 池化复用前重置状态（ObjectPool.acquire 调用）
func reset_for_reuse() -> void:
	health = stats.max_health if stats else 40.0
	_contact_cooldown = 0.0
	velocity = Vector2.ZERO
	_apply_visual()

# 刷怪器选种后调用：设定变种参数并按数据应用视觉（染色/体型）
func configure(s: EnemyStats) -> void:
	stats = s
	health = s.max_health
	_contact_cooldown = 0.0
	velocity = Vector2.ZERO
	_apply_visual()

func _apply_visual() -> void:
	var spr: Sprite2D = $Sprite
	if stats:
		spr.modulate = stats.tint
		spr.scale = Vector2.ONE * (0.095 * stats.scale_mult)
	else:
		spr.modulate = Color(1, 1, 1, 1)
		spr.scale = Vector2.ONE * 0.095

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(_player):
		return
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta

	var speed: float = stats.move_speed if stats else 90.0
	# 轻量避障：直线方向前方有障碍柱时切向绕行（无导航网格方案）
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	dir = _steer_around_obstacles(dir)
	velocity = dir * speed
	move_and_slide()

	# 接触掉血（§11.4.3）：贴近玩家且冷却结束才扣一次
	if global_position.distance_to(_player.global_position) < 28.0 and _contact_cooldown <= 0.0:
		_contact_cooldown = 0.8
		var dmg: float = stats.attack_power if stats else 8.0
		_player.take_damage(dmg)

# 前方 90px 射线检测障碍柱：命中则瞄准「柱缘通过点」（柱侧外缘 58px 处）绕行，
# 过柱后射线不再命中即回到直线追踪。其余碰撞体交给 move_and_slide 滑动。
func _steer_around_obstacles(dir: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + dir * 90.0, 1, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty() or not hit.collider.is_in_group("obstacle"):
		return dir
	var to_center: Vector2 = hit.collider.global_position - global_position
	var away: Vector2 = -to_center.normalized()
	var tangent: Vector2 = Vector2(-away.y, away.x)
	if tangent.dot(dir) < 0.0:
		tangent = -tangent
	# 通过点：柱心沿切向偏移 58px（柱半径30 + 自身半径14 + 余量）
	var pass_point: Vector2 = hit.collider.global_position + tangent * 58.0
	return (pass_point - global_position).normalized()

func take_damage(amount: float) -> void:
	if not active:
		return   # 已死/回池中的敌人不再吃伤害，防同帧双杀双计数
	health -= amount
	Juice.add_trauma(0.15)
	Sfx.play("hit")
	if health <= 0:
		_die()

func _die() -> void:
	active = false            # 立即停摆，避免后续子弹同帧再触发
	GameState.register_kill()
	Sfx.play("kill")
	# 树操作不能发生在物理回调内，延后到帧末
	_deferred_die.call_deferred()

func _deferred_die() -> void:
	_drop_loot()
	# 击杀爆裂粒子：复制一份留在原地播完（本体带原粒子节点回池）
	if is_instance_valid(particles):
		var burst: GPUParticles2D = particles.duplicate() as GPUParticles2D
		burst.global_position = global_position
		get_tree().current_scene.add_child(burst)
		burst.emitting = true
		var p := burst
		get_tree().create_timer(0.8).timeout.connect(Callable(p, "queue_free"))
	var pool: Node = get_meta("pool", null)
	if pool:
		pool.release(self)
	else:
		queue_free()

# 死亡掉落：50% 孢子晶体（加分）；10% 医疗包（仅玩家未满血时才掉，
# 满血不掉避免浪费）。低频生成，直接 instantiate（不值得入池）。
func _drop_loot() -> void:
	var r := randf()
	var kind := ""
	if r < 0.10:
		var p: Node = get_tree().get_first_node_in_group("player")
		if p and "health" in p and p.health < p.get("max_health"):
			kind = "heal"
	elif r < 0.60:
		kind = "crystal"
	if kind == "":
		return
	var pk: Node2D = PICKUP_SCENE.instantiate()
	pk.kind = kind
	pk.position = global_position   # 先摆位再入树（池化教训同款）
	get_tree().current_scene.add_child(pk)
