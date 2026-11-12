extends CharacterBody2D
# 自动索敌 + 接触掉血 + 受击 + 死亡回收（§11.4.2 / §11.4.3）。
# 用 NavigationAgent2D 走避障路径，绕开竞技场中央的障碍柱；
# 目标实时设为玩家位置，由导航网格算出绕障路点。
# 池化（§11.9）：死亡不再 queue_free，归还 ObjectPool 复用；粒子改为「复制一份留在原地爆」，
# 本体带着粒子节点回池，保证每次死亡都有击杀爆裂。

const BASE_SCALE := 0.19   # 贴图主体已归一化（210/256），该值对应杂兵约 40px 屏幕尺寸

@export var stats: EnemyStats

const PICKUP_SCENE := preload("res://scenes/world/Pickup.tscn")

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var particles: GPUParticles2D = $KillParticles
@onready var outline: Sprite2D = $Outline

var _default_tex: Texture2D

var active: bool = true
var health: float = 40.0
var max_health: float = 40.0
var is_boss: bool = false
var _player: Node2D
var _contact_cooldown: float = 0.0
var _base_tint: Color = Color.WHITE

# Boss 冲锋状态机：0 追击蓄势 / 1 前摇（可读的威胁预警）/ 2 突进
var _charge_state: int = 0
var _charge_t: float = 0.0
var _charge_cd: float = 3.4
var _charge_dir: Vector2 = Vector2.RIGHT
# 避障射线节流（§11.7 压测优化）：近距离直接贴脸不打射线；远距离 0.12s 缓存一次，
# 200 只同屏时射线调用量从 12000/s 降到约 1600/s。
var _steer_t: float = 0.0
var _steer_dir: Vector2 = Vector2.ZERO

# 伏击状态机（§11.5 伏击体）：0 = 无伏击/已进入追击，1 = 潜伏（半埋半透明、静止），
# 2 = 破土前摇。潜伏中不吃接触伤害，玩家进入警觉半径才炸出来高速追击。
var _ambush_state: int = 0
var _ambush_t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE * 0.095

func _ready() -> void:
	add_to_group("enemy")
	_default_tex = $Sprite.texture   # 池化复用的贴图还原基准
	if stats:
		health = stats.max_health
	_player = get_tree().get_first_node_in_group("player")
	# 画质档位注册（§11.6）：描边 pass 与击杀粒子密度
	Quality.register_outline(outline)
	Quality.register_particles(particles)
	# 延后一帧等导航地图同步完成（Godot 4.x 推荐），再配置 agent 参数
	await get_tree().physics_frame
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0

# 池化复用前重置状态（ObjectPool.acquire 调用）
func reset_for_reuse() -> void:
	max_health = stats.max_health if stats else 40.0
	health = max_health
	is_boss = stats.is_boss if stats else false
	_contact_cooldown = 0.0
	velocity = Vector2.ZERO
	_charge_state = 0
	_charge_t = 0.0
	_charge_cd = stats.charge_interval if stats else 3.4
	_steer_t = 0.0
	_steer_dir = Vector2.ZERO
	_base_tint = stats.tint if stats else Color.WHITE
	_setup_ambush(stats != null and not stats.is_boss and stats.behavior == "ambush")
	_apply_visual()

# 刷怪器选种后调用：设定变种参数并按数据应用视觉（染色/体型）
# hp_mult：Boss 每轮出现按血量倍率递增，避免后期武器成长后秒杀
func configure(s: EnemyStats, hp_mult: float = 1.0) -> void:
	stats = s
	is_boss = s.is_boss
	max_health = s.max_health * hp_mult
	health = max_health
	_contact_cooldown = 0.0
	velocity = Vector2.ZERO
	_charge_state = 0
	_charge_t = 0.0
	_charge_cd = s.charge_interval
	_steer_t = 0.0
	_steer_dir = Vector2.ZERO
	_base_tint = s.tint
	_apply_visual()
	_setup_ambush(not s.is_boss and s.behavior == "ambush")
	if is_boss:
		add_to_group("boss")
	else:
		remove_from_group("boss")   # 池化复用：Boss 退回杂兵时清掉分组

# 潜伏/常规初始化（伏击体半埋，其余满状态登场）
func _setup_ambush(enabled: bool) -> void:
	if enabled:
		_ambush_state = 1
		_ambush_t = 0.0
		modulate.a = 0.45
	else:
		_ambush_state = 0
		_ambush_t = 0.0
		modulate.a = 1.0

func _apply_visual() -> void:
	var spr: Sprite2D = $Sprite
	var tex: Texture2D = stats.sprite_texture if stats else null
	if stats:
		spr.modulate = stats.tint
		spr.scale = Vector2.ONE * (BASE_SCALE * stats.scale_mult)
	else:
		spr.modulate = Color.WHITE
		spr.scale = Vector2.ONE * BASE_SCALE
	# 变种专属贴图（池化复用必须双向切：挂上/还原默认）
	spr.texture = tex if tex else _default_tex
	_base_scale = spr.scale
	# 描边层必须跟着体型与贴图走，否则大块头会露出「一圈看不见的边」
	if is_instance_valid(outline):
		outline.texture = spr.texture
		outline.scale = spr.scale

func _restore_tint() -> void:
	var spr: Sprite2D = $Sprite
	spr.modulate = _base_tint

# 血渍颜色：数据驱动优先（blood_color 显式配置），未配置时回退 tint 调暗
# （walker 的 tint 是白色——它的青色在贴图里——所以每个 .tres 都显式写了血色）
func _blood_color() -> Color:
	if stats and stats.blood_color.a > 0.5:
		return stats.blood_color
	if stats:
		return Color(stats.tint.r * 0.55, stats.tint.g * 0.55, stats.tint.b * 0.55)
	return Color(0.16, 0.55, 0.5)

# 前摇染色：Boss 蓄力时整只精灵被推亮成血红色，玩家一眼读懂「要冲了」
func _flash_tint(c: Color, dur: float) -> void:
	var spr: Sprite2D = $Sprite
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(spr, "modulate", c, dur)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(_player):
		return
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta

	var speed: float = stats.move_speed if stats else 90.0
	var to_player: Vector2 = _player.global_position - global_position
	var dir: Vector2 = to_player.normalized()

	# 伏击体状态机：潜伏（静止、不吃伤害）→ 破土前摇 → 并入常规追击
	if _ambush_state == 1:
		velocity = Vector2.ZERO
		var alert: float = stats.alert_radius if stats else 320.0
		if to_player.length() < alert:
			_ambush_state = 2
			_ambush_t = 0.35
			Sfx.play("hit", 0.6, 2.0)
			Juice.add_trauma(0.12)
			_flash_tint(Color(1.0, 0.5, 0.5), 0.12)
		move_and_slide()
		return
	elif _ambush_state == 2:
		velocity = Vector2.ZERO
		_ambush_t -= delta
		if _ambush_t <= 0.0:
			_ambush_state = 0
			modulate.a = 1.0
			_restore_tint()
			_emerge_pop()
		move_and_slide()
		return

	if is_boss:
		_boss_update(delta, speed, dir)
	elif to_player.length() < 140.0:
		# 贴身阶段直接朝玩家推：省掉射线，也避免在玩家身边绕圈打转
		velocity = dir * speed
	else:
		# 轻量避障：直线方向前方有障碍柱时切向绕行（无导航网格方案），节流缓存
		_steer_t -= delta
		if _steer_t <= 0.0:
			_steer_t = 0.12
			_steer_dir = _steer_around_obstacles(dir)
		velocity = _steer_dir * speed
	move_and_slide()

	# 接触掉血（§11.4.3）：贴近玩家且冷却结束才扣一次；冲锋命中额外加成
	var reach: float = stats.contact_radius if stats else 26.0
	if global_position.distance_to(_player.global_position) < reach and _contact_cooldown <= 0.0:
		_contact_cooldown = 0.65 if is_boss else 0.8
		var dmg: float = stats.attack_power if stats else 8.0
		if is_boss and _charge_state == 2:
			dmg *= 1.6
		_player.take_damage(dmg)

# 破土弹跳：本体与描边层一起放大再回落（只动 Sprite，不碰物理碰撞体的 scale）
func _emerge_pop() -> void:
	var spr: Sprite2D = $Sprite
	var popped: Vector2 = _base_scale * 1.22
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(spr, "scale", popped, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var back := create_tween()
	back.set_ignore_time_scale(true)
	back.tween_property(spr, "scale", _base_scale, 0.14).set_delay(0.08)
	if is_instance_valid(outline):
		var t2 := create_tween()
		t2.set_ignore_time_scale(true)
		t2.tween_property(outline, "scale", popped, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var b2 := create_tween()
		b2.set_ignore_time_scale(true)
		b2.tween_property(outline, "scale", _base_scale, 0.14).set_delay(0.08)

# Boss 专用移动：常规追击 → 蓄力前摇（站桩+变色+低频吼）→ 高速突进 → 冷却。
# 前摇 0.55s 是「可躲窗口」：玩家 220px/s 能在突进路径上侧移出判定圈。
# Boss 不做绕障（体型大、直线冲锋更符合直觉），撞柱交给 move_and_slide 滑动。
func _boss_update(delta: float, speed: float, dir: Vector2) -> void:
	match _charge_state:
		0:
			_charge_cd -= delta
			velocity = dir * speed
			if _charge_cd <= 0.0 and global_position.distance_to(_player.global_position) < 560.0:
				_charge_state = 1
				_charge_t = 0.55
				velocity = Vector2.ZERO
				_flash_tint(Color(1.0, 0.32, 0.32), 0.12)
				Sfx.play("hurt", 0.45, 2.0)
		1:
			velocity = Vector2.ZERO
			_charge_t -= delta
			if _charge_t <= 0.0:
				_charge_state = 2
				_charge_t = 0.45
				_charge_dir = dir
				_flash_tint(Color(1.0, 0.94, 0.9), 0.08)
		2:
			velocity = _charge_dir * speed * (stats.charge_speed if stats else 4.2)
			_charge_t -= delta
			if _charge_t <= 0.0:
				_charge_state = 0
				_charge_cd = stats.charge_interval if stats else 3.4
				_restore_tint()
				Juice.add_trauma(0.18)

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
	if is_boss:
		EventBus.boss_damaged.emit(maxf(health, 0.0), max_health)
	if health <= 0:
		_die()

func _die() -> void:
	active = false            # 立即停摆，避免后续子弹同帧再触发
	GameState.register_kill(stats.score_value if stats else 10)
	if is_boss:
		GameState.boss_active = false
		Juice.add_trauma(0.95)
		Sfx.play("hurt", 0.4, 4.0)
		EventBus.boss_defeated.emit(stats.display_name if stats else "ELITE")
	else:
		Sfx.play("kill")
	# 树操作不能发生在物理回调内，延后到帧末
	_deferred_die.call_deferred()

func _deferred_die() -> void:
	_drop_loot()
	# 血水残迹：留一滩对应变种颜色的体液渍，溅开 → 存留数秒 → 淡出（§11.4.3 击杀反馈）
	var blood: Color = _blood_color()
	BloodPool.spawn(get_tree().current_scene, global_position, blood,
		stats.scale_mult if stats else 1.0)
	# 击杀爆裂粒子：复制一份留在原地播完（本体带原粒子节点回池）
	# Boss 放三重爆裂并放大尺寸，做成「高潮收尾」的视觉标点
	var bursts: int = 3 if is_boss else 1
	for i in bursts:
		if not is_instance_valid(particles):
			break
		var burst: GPUParticles2D = particles.duplicate() as GPUParticles2D
		burst.global_position = global_position
		if is_boss:
			burst.scale = Vector2.ONE * (1.0 + i * 0.55)
			burst.global_position += Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0))
		get_tree().current_scene.add_child(burst)
		burst.emitting = true
		var p := burst
		get_tree().create_timer(0.8 + i * 0.18).timeout.connect(Callable(p, "queue_free"))
	var pool: Node = get_meta("pool", null)
	if pool:
		pool.release(self)
	else:
		queue_free()

# 死亡掉落：Boss 固定撒一圈晶体 + 1 个医疗包（打完全场唯一补给点）；
# 杂兵 50% 孢子晶体（加分）；10% 医疗包（仅玩家未满血时才掉，满血不掉避免浪费）。
func _drop_loot() -> void:
	if is_boss:
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			_spawn_pickup("crystal", global_position + Vector2(cos(a), sin(a)) * 42.0)
		_spawn_pickup("heal", global_position + Vector2(0.0, -46.0))
		return
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
	_spawn_pickup(kind, global_position)

func _spawn_pickup(kind: String, pos: Vector2) -> void:
	var pk: Node2D = PICKUP_SCENE.instantiate()
	pk.kind = kind
	pk.position = pos   # 先摆位再入树（池化教训同款）
	get_tree().current_scene.add_child(pk)
