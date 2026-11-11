extends CharacterBody2D
# 自动索敌 + 接触掉血 + 受击 + 死亡掉落（§11.4.2 / §11.4.3）。
# 用 NavigationAgent2D 走避障路径，绕开竞技场中央的障碍柱；
# 目标实时设为玩家位置，由导航网格算出绕障路点。

@export var stats: EnemyStats

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var particles: GPUParticles2D = $KillParticles

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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta

	var speed: float = stats.move_speed if stats else 90.0
	# 避障寻路：把玩家设为导航目标，沿下一路径点前进
	nav_agent.target_position = _player.global_position
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	if global_position.distance_to(next_pos) > 2.0:
		var dir: Vector2 = (next_pos - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# 接触掉血（§11.4.3）：贴近玩家且冷却结束才扣一次
	if global_position.distance_to(_player.global_position) < 28.0 and _contact_cooldown <= 0.0:
		_contact_cooldown = 0.8
		var dmg: float = stats.attack_power if stats else 8.0
		_player.take_damage(dmg)

func take_damage(amount: float) -> void:
	health -= amount
	Juice.add_trauma(0.15)
	if health <= 0 and is_instance_valid(self):
		_die()

func _die() -> void:
	GameState.register_kill()
	# 击杀爆裂粒子：移到父级后再释放本体，让粒子播完
	if is_instance_valid(particles):
		particles.reparent(get_parent())
		particles.emitting = true
		var p := particles
		get_tree().create_timer(0.8).timeout.connect(Callable(p, "queue_free"))
	queue_free()
