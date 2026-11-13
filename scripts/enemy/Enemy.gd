extends CharacterBody2D
# 自动索敌 + 接触掉血 + 受击 + 死亡回收（§11.4.2 / §11.4.3）。
# 杂兵追击用 NavigationAgent2D：Arena 会把固定方柱和随机柱烘焙成洞，这里沿下一路径点走。
# Boss 不寻路，直线冲锋，撞柱交给 move_and_slide。
# 池化（§11.9）：死亡不再 queue_free，归还 ObjectPool 复用；粒子改为「复制一份留在原地爆」，
# 本体带着粒子节点回池，保证每次死亡都有击杀爆裂。
# §11.12 远程变种：射程带内站桩前摇后开火（毒针单发 / 毒液扇喷），太近收枪转贴身。
# §11.13 Boss 技能组：与冲锋独立冷却，非冲锋状态施放三技能（弹幕环/剧毒喷息/巢群召唤）。

const BASE_SCALE := 0.19   # 贴图主体已归一化（210/256），该值对应杂兵约 40px 屏幕尺寸

@export var stats: EnemyStats

const PICKUP_SCENE := preload("res://scenes/world/Pickup.tscn")
const ENEMY_BULLET_SCENE := preload("res://scenes/world/EnemyBullet.tscn")

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

# Boss 冲锋状态机：0 追击蓄势 / 1 前摇（可读的威胁预警）/ 2 突进 / 3 技能前摇
var _charge_state: int = 0
var _charge_t: float = 0.0
var _charge_cd: float = 3.4
var _charge_dir: Vector2 = Vector2.RIGHT
# 寻路节流：target_position 每次赋值都会发一次查询，不能每帧打。
const NAV_REPATH_SEC := 0.20
var _nav_repath_t: float = 0.0

# 伏击状态机（§11.5 伏击体）：0 = 无伏击/已进入追击，1 = 潜伏（半埋半透明、静止），
# 2 = 破土前摇。潜伏中不吃接触伤害，玩家进入警觉半径才炸出来高速追击。
var _ambush_state: int = 0
var _ambush_t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE * 0.095
# 分裂孢子体（§11.5 M4）：实例级视觉缩放 + 防递归标记，池化复用必须清零
var _is_split_child: bool = false
var _size_mult: float = 1.0

# 远程攻击状态机（§11.12）：0 追击 / 1 站桩蓄射前摇
var _ranged_state: int = 0
var _ranged_t: float = 0.0
var _ranged_cd: float = 0.0

# Boss 技能（§11.13）：独立于冲锋的冷却；0 弹幕环 / 1 剧毒喷息 / 2 巢群召唤
var _skill_cd: float = 4.0
var _skill_pending: int = 0
var _last_skill: int = -1

func _ready() -> void:
	add_to_group("enemy")
	_default_tex = $Sprite.texture   # 池化复用的贴图还原基准
	if stats:
		health = stats.max_health
	_player = get_tree().get_first_node_in_group("player")
	# 画质档位注册（§11.6）：描边 pass 与击杀粒子密度
	Quality.register_outline(outline)
	Quality.register_particles(particles)
	nav_agent.path_desired_distance = 16.0
	nav_agent.target_desired_distance = 10.0
	# 池里停放的个体不要每帧做寻路查询；出场后 _physics_process 再打开
	nav_agent.set_physics_process(false)

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
	_nav_repath_t = 0.0
	_base_tint = stats.tint if stats else Color.WHITE
	_is_split_child = false          # 池化复用：清掉上一只的分裂子体标记
	_size_mult = 1.0
	_setup_ambush(stats != null and not stats.is_boss and stats.behavior == "ambush")
	_ranged_state = 0
	_ranged_t = 0.0
	_ranged_cd = _first_ranged_cd()
	_skill_cd = 4.0
	_last_skill = -1
	_apply_visual()

# 刷怪器选种后调用：设定变种参数并按数据应用视觉（染色/体型）
# hp_mult：Boss 每轮出现按血量倍率递增，避免后期武器成长后秒杀
func configure(s: EnemyStats, hp_mult: float = 1.0, is_split_child: bool = false) -> void:
	stats = s
	_is_split_child = is_split_child
	_size_mult = s.split_size_mult if is_split_child else 1.0
	is_boss = s.is_boss
	max_health = s.max_health * hp_mult
	health = max_health
	_contact_cooldown = 0.0
	velocity = Vector2.ZERO
	_charge_state = 0
	_charge_t = 0.0
	_charge_cd = s.charge_interval
	_nav_repath_t = 0.0
	_base_tint = s.tint
	_setup_ambush(not s.is_boss and s.behavior == "ambush")
	_ranged_state = 0
	_ranged_t = 0.0
	_ranged_cd = _first_ranged_cd()
	_skill_cd = 4.0
	_last_skill = -1
	_apply_visual()
	if is_boss:
		add_to_group("boss")
	else:
		remove_from_group("boss")   # 池化复用：Boss 退回杂兵时清掉分组

# 首次开火延迟：进场先追一小段，别一刷出来就隔屏狙击（远程怪 1.2s，其余值无意义）
func _first_ranged_cd() -> float:
	if stats and stats.ranged_attack != "" and not stats.is_boss:
		return 1.2
	return stats.ranged_interval if stats else 2.6

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
		spr.scale = Vector2.ONE * (BASE_SCALE * stats.scale_mult * _size_mult)
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

# 前摇染色：Boss 蓄力时整只精灵被推亮，玩家一眼读懂「要出招了」
func _flash_tint(c: Color, dur: float) -> void:
	var spr: Sprite2D = $Sprite
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(spr, "modulate", c, dur)

func _set_nav_query(enabled: bool) -> void:
	if nav_agent.is_physics_processing() == enabled:
		return
	nav_agent.set_physics_process(enabled)
	if enabled:
		_nav_repath_t = 0.0

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(_player):
		_set_nav_query(false)
		return
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta
	_tick_burn(delta)

	var speed: float = stats.move_speed if stats else 90.0
	var to_player: Vector2 = _player.global_position - global_position
	var dir: Vector2 = to_player.normalized()
	var dist: float = to_player.length()

	# 伏击体状态机：潜伏（静止、不吃伤害）→ 破土前摇 → 并入常规追击
	if _ambush_state == 1:
		_set_nav_query(false)
		velocity = Vector2.ZERO
		var alert: float = stats.alert_radius if stats else 320.0
		if dist < alert:
			_ambush_state = 2
			_ambush_t = 0.35
			Sfx.play("hit", 0.6, 2.0)
			Juice.add_trauma(0.12)
			_flash_tint(Color(1.0, 0.5, 0.5), 0.12)
		move_and_slide()
		return
	elif _ambush_state == 2:
		_set_nav_query(false)
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
		# Boss 直线冲锋，不走导航；关掉查询，避免停放/冲锋时朝默认目标空打寻路
		_set_nav_query(false)
		_boss_update(delta, speed, dir, dist)
	else:
		_mob_update(delta, speed, dir, dist)
	move_and_slide()

	# 接触掉血（§11.4.3）：贴近玩家且冷却结束才扣一次；冲锋命中额外加成
	var reach: float = (stats.contact_radius if stats else 26.0) * _size_mult
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

# 杂兵移动 + 远程攻击（§11.12）：射程带内冷却好 → 站桩蓄射（染色预警）→ 开火；
# 太近（< min_range）或冷却中 → 照常追击，玩家贴脸即可破解远程。
func _mob_update(delta: float, speed: float, dir: Vector2, dist: float) -> void:
	var r_atk: String = stats.ranged_attack if stats else ""
	if r_atk == "":
		_chase(delta, speed, dir, dist)
		return
	if _ranged_state == 1:
		# 蓄射前摇：站桩，读条完朝玩家当前位置开火
		_set_nav_query(false)
		velocity = Vector2.ZERO
		_ranged_t -= delta
		if _ranged_t <= 0.0:
			_fire_ranged(r_atk)
			_ranged_state = 0
			_ranged_cd = stats.ranged_interval
			_restore_tint()
		return
	# 冷却 + 距离带判定
	_ranged_cd -= delta
	var in_band: bool = dist <= stats.ranged_range and dist >= stats.ranged_min_range
	if _ranged_cd <= 0.0 and in_band:
		_set_nav_query(false)
		_ranged_state = 1
		_ranged_t = stats.ranged_windup
		velocity = Vector2.ZERO
		_flash_tint(Color(0.75, 1.0, 0.45), stats.ranged_windup * 0.6)
	else:
		_chase(delta, speed, dir, dist)

# 近战/远程共用的追击：沿导航网格的下一路径点走，柱子被烘焙成洞后会绕开。
# 路径还没返回时（下一站就在脚下）先朝玩家直线走，避免出生那一帧站桩。
func _chase(delta: float, speed: float, dir: Vector2, _dist: float) -> void:
	_set_nav_query(true)
	_nav_repath_t -= delta
	if _nav_repath_t <= 0.0:
		_nav_repath_t = NAV_REPATH_SEC
		nav_agent.target_position = _player.global_position
	var next: Vector2 = nav_agent.get_next_path_position()
	var to_next: Vector2 = next - global_position
	if to_next.length_squared() <= 36.0:
		velocity = dir * speed
	else:
		velocity = to_next.normalized() * speed

# 远程开火（§11.12）：needle 单发速射 + 挂毒；venom 扇形毒液 + 落地毒云
func _fire_ranged(kind: String) -> void:
	if not is_instance_valid(_player):
		return
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	var dmg: float = stats.attack_power * stats.ranged_damage_mult
	var spawn_pos: Vector2 = global_position + dir * 20.0
	if kind == "needle":
		Sfx.play("shoot", 1.4, -4.0)
		_spawn_bullet(spawn_pos, dir, dmg, 460.0, {
			"kind": "needle",
			"poison_dps": stats.ranged_poison_dps,
			"poison_time": stats.ranged_poison_time,
			"lifetime": 1.4,
		})
	else:
		Sfx.play("spit", 1.0)
		var n: int = maxi(1, stats.spray_count)
		var half: float = deg_to_rad(stats.spray_spread_deg) * 0.5
		for i in n:
			var a: float = -half + (2.0 * half * float(i) / maxf(float(n - 1), 1.0)) if n > 1 else 0.0
			_spawn_bullet(spawn_pos, dir.rotated(a), dmg, 240.0, {
				"kind": "venom",
				"poison_dps": stats.ranged_poison_dps,
				"poison_time": stats.ranged_poison_time,
				"leaves_cloud": stats.leaves_cloud,
				"cloud_radius": stats.cloud_radius,
				"cloud_duration": stats.cloud_duration,
				"cloud_dps": stats.cloud_dps,
				"lifetime": 1.6,
			})

func _spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, spd: float, opts: Dictionary) -> void:
	if EnemyBullet._alive_count >= EnemyBullet.ALIVE_CAP:
		return   # 弹幕硬上限，防极端情况刷爆
	var b: Area2D = ENEMY_BULLET_SCENE.instantiate()
	b.position = pos   # 先摆位再入树（池化教训同款）
	get_tree().current_scene.add_child(b)
	b.setup(dir, dmg, spd, opts)

# Boss 专用：常规追击 → 蓄力前摇（站桩+变色+低频吼）→ 高速突进 → 冷却；
# 技能独立冷却（§11.13）：非冲锋状态且技能冷却好时，随机三选一施放。
# 前摇 0.55s 是「可躲窗口」：玩家 220px/s 能在突进路径上侧移出判定圈。
# Boss 不做绕障（体型大、直线冲锋更符合直觉），撞柱交给 move_and_slide 滑动。
func _boss_update(delta: float, speed: float, dir: Vector2, dist: float) -> void:
	match _charge_state:
		0:
			_charge_cd -= delta
			_skill_cd -= delta
			velocity = dir * speed
			var can_charge: bool = _charge_cd <= 0.0 and dist < 560.0
			var can_skill: bool = _skill_cd <= 0.0 and dist < (stats.skill_range if stats else 640.0)
			if can_skill and not can_charge:
				# 优先冲锋时机让位（贴脸冲锋威胁更直接）；反之技能先手
				_begin_skill(dist)
			elif can_charge:
				_charge_state = 1
				_charge_t = 0.55
				velocity = Vector2.ZERO
				_flash_tint(Color(1.0, 0.32, 0.32), 0.12)
				Sfx.play("hurt", 0.45, 2.0)
			elif can_skill:
				_begin_skill(dist)
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
		3:
			# 技能前摇：站桩蓄力（颜色按技能区分），读条完出招
			velocity = Vector2.ZERO
			_charge_t -= delta
			if _charge_t <= 0.0:
				_cast_skill()

# 随机三选一（不连续重复同一招），按技能定前摇时长与预警色
func _begin_skill(dist: float) -> void:
	var pool: Array[int] = [0, 1]
	if stats and stats.summon_stats != null:
		pool.append(2)   # 没配召唤谱就只在弹幕/喷息里选
	if pool.has(_last_skill) and pool.size() > 1:
		pool.erase(_last_skill)
	_skill_pending = pool[randi() % pool.size()]
	_last_skill = _skill_pending
	_charge_state = 3
	_charge_t = 0.55 if _skill_pending != 2 else 0.7
	velocity = Vector2.ZERO
	match _skill_pending:
		0: _flash_tint(Color(0.85, 0.45, 1.0), 0.12)   # 弹幕环：紫
		1: _flash_tint(Color(0.65, 1.0, 0.4), 0.12)    # 剧毒喷息：毒绿
		2: _flash_tint(Color(1.0, 0.94, 0.75), 0.12)   # 巢群召唤：暖白
	Sfx.play("hurt", 0.6, 3.0)

# 技能出招瞬间：弹全部立即生成（扇形瞄准玩家当前位置），随后回追击态
func _cast_skill() -> void:
	_charge_state = 0
	_charge_cd = maxf(_charge_cd, 1.2)   # 出招后冲锋至少再等 1.2s，节奏可读
	_skill_cd = stats.skill_interval if stats else 5.5
	_restore_tint()
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	var dmg: float = stats.attack_power * 0.5
	match _skill_pending:
		0:
			# 孢子弹幕：360° 环形中速毒团，无云无毒，纯封锁走位
			Sfx.play("spit", 0.8)
			Juice.add_trauma(0.25)
			var n: int = maxi(6, stats.radial_count)
			var a0: float = randf() * TAU   # 随机起始角，别让玩家背板站位
			for i in n:
				var a: float = a0 + TAU * float(i) / float(n)
				_spawn_bullet(global_position + Vector2(cos(a), sin(a)) * 30.0,
					Vector2(cos(a), sin(a)), dmg, 260.0,
					{"kind": "spore", "lifetime": 2.2, "color": Color(0.85, 0.4, 0.9)})
		1:
			# 剧毒喷息：朝玩家扇形毒液，落地/撞柱留毒云，正面区域封锁
			Sfx.play("spit", 0.9)
			Juice.add_trauma(0.2)
			var n2: int = maxi(3, stats.breath_count)
			var half: float = deg_to_rad(stats.breath_spread_deg) * 0.5
			for i in n2:
				var a2: float = -half + (2.0 * half * float(i) / maxf(float(n2 - 1), 1.0)) if n2 > 1 else 0.0
				_spawn_bullet(global_position + dir * 30.0, dir.rotated(a2),
					dmg * 0.9, 280.0, {
						"kind": "venom",
						"poison_dps": 4.0,
						"poison_time": 2.5,
						"leaves_cloud": true,
						"cloud_radius": 56.0,
						"cloud_duration": 3.5,
						"cloud_dps": 12.0,
						"lifetime": 1.5,
					})
		2:
			# 巢群召唤：从池里取杂兵围在 Boss 周一圈（受同屏上限约束）
			Sfx.play("hurt", 0.7, 4.0)
			Juice.add_trauma(0.3)
			_summon_brood()

# 召唤杂兵：同分裂体一样受 alive<140 上限保护。
# 入场后走杂兵同一套导航追击，会绕开已经烘焙进网格的柱子。
func _summon_brood() -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active"):
			alive += 1
	var budget: int = mini(stats.summon_count if stats else 3, 140 - alive)
	if budget <= 0:
		return
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	if pool == null:
		return
	for i in budget:
		var child: Node2D = pool.acquire(get_tree().current_scene) as Node2D
		if child == null:
			return
		child.configure(stats.summon_stats)
		var a: float = TAU * float(i) / float(budget) + randf() * 0.5
		child.global_position = global_position + Vector2(cos(a), sin(a)) * 80.0

# ---------------- 燃烧 DoT（火弹枪/喷火枪点燃，刷新制不叠加） ----------------
# 静默结算：不走 take_damage 的受击音/屏震，燃烧跳数不会刷屏；直接扣血并判死。
var _burn_dps: float = 0.0
var _burn_time: float = 0.0
var _burn_tick_t: float = 0.0
const BURN_TICK := 0.5

func apply_burn(dps: float, duration: float) -> void:
	if not active:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = duration
	_burn_tick_t = 0.0

func _tick_burn(delta: float) -> void:
	if not active or _burn_time <= 0.0:
		return
	_burn_time -= delta
	_burn_tick_t += delta
	if _burn_tick_t >= BURN_TICK:
		_burn_tick_t -= BURN_TICK
		health -= _burn_dps * BURN_TICK
		if is_boss:
			EventBus.boss_damaged.emit(maxf(health, 0.0), max_health)
		if health <= 0.0:
			_die()


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
	# 被打爆演出：本体立即回池，视觉替身留原地（闪白膨胀 → 贴图碎片+脓滴四散 → 淡出）
	var spr: Sprite2D = $Sprite
	DeathBurst.spawn(get_tree().current_scene, global_position, spr.texture,
		_base_tint, blood, spr.scale.x, stats.scale_mult if stats else 1.0)
	# 变种行为分支（§11.5 M4）：毒雾孢留雾区 / 分裂孢裂出子体
	if stats:
		if stats.behavior == "miasma":
			PoisonCloud.spawn(get_tree().current_scene, global_position,
				stats.poison_radius, stats.poison_duration, stats.poison_dps, blood)
		elif stats.behavior == "split" and not _is_split_child:
			_spawn_splits()
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

# 分裂孢死亡：从池里取 N 只迷你子体（同参数谱、血量与体型按表缩放）。
# 子体带 _is_split_child 标记，死亡时不再分裂，杜绝同帧指数爆炸；
# 场上活跃数接近 150 上限时直接放弃分裂，守住性能底线。
func _spawn_splits() -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active"):
			alive += 1
	if alive >= 140:
		return
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	if pool == null:
		return
	for i in stats.split_count:
		var child: Node2D = pool.acquire(get_tree().current_scene) as Node2D
		if child == null:
			return
		child.configure(stats, stats.split_hp_mult, true)
		var a: float = randf() * TAU
		child.global_position = global_position + Vector2(cos(a), sin(a)) * 30.0

# 死亡掉落：Boss 固定撒一圈晶体 + 1 个医疗包（打完全场唯一补给点）；
# 杂兵 50% 孢子晶体（加分）；10% 医疗包（仅玩家未满血时才掉，满血不掉避免浪费）。
func _drop_loot() -> void:
	# 剧情禁止随机武器箱，避免序章捡到沙漠飞鹰以外的枪。晶体仍可掉，给安全屋换补给。
	if GameState.is_story():
		var story_roll := randf()
		var story_kind := ""
		if story_roll < 0.10:
			var p: Node = get_tree().get_first_node_in_group("player")
			if p and "health" in p and p.health < p.get("max_health"):
				story_kind = "heal"
		elif story_roll < 0.60:
			story_kind = "crystal"
		if story_kind != "":
			_spawn_pickup(story_kind, global_position)
		return
	if is_boss:
		var bwid: String = WeaponDB.random_unowned(GameState.owned_weapons)
		if bwid != "":
			_spawn_pickup("weapon", global_position + Vector2(0.0, 46.0), bwid)
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			_spawn_pickup("crystal", global_position + Vector2(cos(a), sin(a)) * 42.0)
		_spawn_pickup("heal", global_position + Vector2(0.0, -46.0))
		return
	# 武器箱：杂兵 4% 概率掉一把未拥有的武器；全收集后不再掉，落回普通掉落
	if randf() < 0.04:
		var wid: String = WeaponDB.random_unowned(GameState.owned_weapons)
		if wid != "":
			_spawn_pickup("weapon", global_position, wid)
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

func _spawn_pickup(kind: String, pos: Vector2, weapon_id: String = "") -> void:
	var pk: Node2D = PICKUP_SCENE.instantiate()
	pk.kind = kind
	pk.weapon_id = weapon_id
	pk.position = pos   # 先摆位再入树（池化教训同款）
	get_tree().current_scene.add_child(pk)
