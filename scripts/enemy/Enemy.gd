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
const FRAME_PLAYER_SCRIPT := preload("res://scripts/enemy/FramePlayer.gd")

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var particles: GPUParticles2D = $KillParticles
@onready var outline: Sprite2D = $Outline
@onready var link_line: Line2D = $LinkLine

# 帧序列播放器（§11.15）：全部运动来自按序排列的帧图片，不做任何程序化变换
var frames = FRAME_PLAYER_SCRIPT.new()

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

# ---- §Wave3 织理者三阶段（HP 阈值 P1>66% / P2 33~66% / P3<33%）----
var _loom_phase: int = 1
var _loom_is_active: bool = false   # 仅 behavior == "loomweaver" 时启用

# ---- Wave 3 新变种状态机（§11.14 Mirror Spore / §11.16 Linker / §11.17 Crystal Wraith）----
# mirror_cache：记录玩家最近移动方向 FIFO，满 mirror_cache_size 条即触发镜像 burst
var _mirror_cache: Array[Vector2] = []
var _mirror_burst_cd: float = 0.0         # 两次 mirror burst 间隔计时器
# link_partner_id：链结对另只 linker 的 instance_id，-1 表示无对家
var _link_partner_id: int = -1
# link_share_incoming：本次伤害是否由对家分摊而来（防递归反弹）
var _link_share_incoming: bool = false
# wraith_crystal_count：场上晶体快照数（每 frame_steal_interval 秒刷新一次，避免每帧遍历 pickup）
var _wraith_crystal_count: int = 0
var _wraith_steal_t: float = 0.0          # 偷晶体计时器
# wraith 追踪弹速度倍数（比 normal bullet 慢 15%，保持「低追踪度」感观）
const WRAITH_BULLET_SPEED_MULT := 0.85

# §11.16 链结对静态注册表（类级字典）：key=instance_id，value=对家的 instance_id
# 替代全局 Autoload LinkSystem，避免与 Node tree 生命周期绑定且零耦合。
var _static_links: Dictionary = {}

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
	# ── Wave 3 状态清零 ──
	_mirror_cache.clear()
	_mirror_burst_cd = 0.0
	if _link_partner_id != -1:
		_dissolve_link()
	_link_partner_id = -1
	_link_share_incoming = false
	_wraith_crystal_count = 0
	_wraith_steal_t = 0.0

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
	_loom_is_active = (s.behavior == "loomweaver")
	_loom_phase = 1
	_apply_visual()
	if is_boss:
		add_to_group("boss")
	else:
		remove_from_group("boss")   # 池化复用：Boss 退回杂兵时清掉分组
	# ── Wave 3 trait setup（按 behavior 分支初始化专属状态）──
	_setup_wave3_traits(s.behavior)

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

# ── Wave 3 trait 初始化钩子（§11.14–17）──
# mirror / linker / wraith 各有专属状态需要 reset；false_bloom 无需额外初始化
func _setup_wave3_traits(behavior: String) -> void:
	_mirror_cache.clear()
	_mirror_burst_cd = 0.0
	_wraith_crystal_count = 0
	_wraith_steal_t = 0.0
	if _link_partner_id != -1:
		_dissolve_link()
	_link_partner_id = -1
	_link_share_incoming = false
	match behavior:
		"mirror":
			_mirror_burst_cd = 0.0   # 开局即冷却好
		"linker":
			# 链结对由 Spawner 在 spawn 后通过 LinkSystem.register 建立
			pass
		"wraith":
			# 蚀晶孢首次进入 _physics_process 时会在 chase 分支里刷新晶体计数
			pass
		"false_bloom":
			pass

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
	# 换怪 / 池化复用时重新绑定帧序列。key 由贴图文件名推导
	# （enemy_corroder.png -> corroder），无需给 13 个 .tres 加字段。
	var key := ""
	if tex:
		key = tex.resource_path.get_file().get_basename().trim_prefix("enemy_")
	frames.setup(spr, outline, key, tex if tex else _default_tex)

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

# 帧播放走独立 _process：纯视觉逻辑，不该依赖 _player 存在或玩法状态机的早退。
# 放在 _physics_process 里会因为「玩家死亡 / 切场景 / 潜伏分支 return」而整体僵住。
func _process(delta: float) -> void:
	if active:
		frames.tick(delta)
		_update_link_line()
	elif is_instance_valid(link_line) and link_line.visible:
		link_line.visible = false

## §11.16 Linker 视觉：把到对家的能量索画出来（局部坐标，随本体移动）。
## 只由 instance_id 较小的一方绘制，避免两条线叠加成双倍亮度。
func _update_link_line() -> void:
	if not is_instance_valid(link_line):
		return
	if _link_partner_id == -1 or get_instance_id() > _link_partner_id:
		link_line.visible = false
		return
	var partner_node: Node = _find_enemy_by_id(_link_partner_id)
	if partner_node == null or not is_instance_valid(partner_node) or not partner_node.get("active"):
		link_line.visible = false
		return
	var local_target: Vector2 = to_local(partner_node.global_position)
	link_line.points = PackedVector2Array([Vector2.ZERO, local_target])
	link_line.visible = true

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

	# ── Wave 3 行为分流（优先级高于常规 mob_update / boss_update）──
	if is_boss:
		# Boss 直线冲锋，不走导航；关掉查询，避免停放/冲锋时朝默认目标空打寻路
		_set_nav_query(false)
		_boss_update(delta, speed, dir, dist)
	elif stats.behavior == "mirror":
		# §11.14 镜影孢：站桩不追，只记录玩家移动方向；缓存满则 burst 射出反射弹
		_set_nav_query(false)
		velocity = Vector2.ZERO
		_mirror_burst_cd -= delta
		# FIFO：每 frame 记录一次 player 相对我们的方向（归一化，保留符号防反向）
		_mirror_cache.push_back(dir)
		if _mirror_cache.size() > (stats.mirror_cache_size if stats else 3):
			_mirror_cache.pop_front()
		if _mirror_burst_cd <= 0.0 and _mirror_cache.size() >= (stats.mirror_cache_size if stats else 3):
			_try_mirror_burst()
			_mirror_burst_cd = stats.mirror_burst_interval if stats else 3.0
		move_and_slide()
		return
	elif stats.behavior == "wraith":
		# §11.17 蚀晶孢：移动速度随场上晶体数线性加速；定期偷取最近一颗晶体
		speed = speed + minf((stats.wraith_crystal_boost_per_crystal if stats else 2.5) * _count_ground_crystals(), 40.0)
		_wraith_steal_t -= delta
		if _wraith_steal_t <= 0.0 and _count_ground_crystals() >= 1:
			_steal_nearest_crystal()
			_wraith_steal_t = stats.wraith_steal_interval if stats else 3.0
		_chase(delta, speed, dir, dist)
		move_and_slide()
		return
	else:
		# 非 boss、非 Wave 3 新变种 → 走原有追击/远程逻辑
		if not is_boss:
			_mob_update(delta, speed, dir, dist)
		else:
			_set_nav_query(false)
			_boss_update(delta, speed, dir, dist)
	move_and_slide()

	# 接触掉血（§11.4.3）：贴近玩家且冷却结束才扣一次；冲锋命中额外加成
	var reach: float = (stats.contact_radius if stats else 26.0) * _size_mult
	if global_position.distance_to(_player.global_position) < reach and _contact_cooldown <= 0.0:
		_contact_cooldown = 0.65 if is_boss else 0.8
		var dmg: float = stats.attack_power if stats else 8.0
		if is_boss and _charge_state == 2:
			dmg *= 1.6
		frames.play_once()   # 贴身撞击：播放单次攻击帧序列
		_player.take_damage(dmg)

# 破土出场：播放单次动作帧序列（帧图是唯一运动来源，不做任何几何变换）。
func _emerge_pop() -> void:
	frames.play_once()   # 破土：播放单次动作帧序列

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
	frames.play_once()   # 开火：播放单次攻击帧序列
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
				frames.play_once()   # 冲锋起手：播放单次动作帧序列
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

# 随机选招（不连续重复），按阶段扩展技能池：
# P1 弹幕/喷息；P2 加「克隆降临」(技能3)；P3 加「覆写协议」(技能4，方案B实装)
# 这里先让 P2/P3 的选招池与预警色生效，强度递增在 _cast_skill。
func _begin_skill(dist: float) -> void:
	var pool: Array[int] = [0, 1]
	if stats and stats.summon_stats != null:
		pool.append(2)   # 没配召唤谱就只在弹幕/喷息里选
	if _loom_is_active and _loom_phase >= 2:
		pool.append(3)   # 克隆降临：方案A 先复用召唤逻辑，方案B 换成真幻影
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
		3: _flash_tint(Color(0.55, 0.75, 1.0), 0.12)   # 克隆降临：电蓝
	Sfx.play("hurt", 0.6, 3.0)

# 技能出招瞬间：弹全部立即生成（扇形瞄准玩家当前位置），随后回追击态
func _cast_skill() -> void:
	_charge_state = 0
	_charge_cd = maxf(_charge_cd, 1.2)   # 出招后冲锋至少再等 1.2s，节奏可读
	_skill_cd = stats.skill_interval if stats else 5.5
	frames.play_once()   # 技能释放：播放单次动作帧序列
	_restore_tint()
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	var dmg: float = stats.attack_power * 0.5
	match _skill_pending:
		0:
			# 孢子弹幕：360° 环形中速毒团，无云无毒，纯封锁走位
			# §Wave3 P2 弹数 +2 / P3 +4（文档：6→8），阶段越高封锁越密
			Sfx.play("spit", 0.8)
			Juice.add_trauma(0.25)
			var phase_bonus: int = 0 if not _loom_is_active else (0 if _loom_phase == 1 else (2 if _loom_phase == 2 else 4))
			var n: int = maxi(6, stats.radial_count) + phase_bonus
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
		3:
			# 克隆降临（方案A：复用召唤谱作为幻影的临时实现）
			# 方案B 会替换成真正的「受击不扣血 + 2s 自毁掉伪晶体」幻影单位
			Sfx.play("hurt", 0.8, 5.0)
			Juice.add_trauma(0.35)
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
	# §11.16 Linker：按比例把伤害分摊给链结对家。
	# _link_share_incoming 标记「这一击是由对家分摊过来的」，防止 A→B→A 递归反弹。
	if _link_partner_id != -1 and not _link_share_incoming:
		amount = _split_damage_to_partner(amount)
	health -= amount
	frames.play_once()   # 受击：播放单次动作帧序列
	Juice.add_trauma(0.15)
	Sfx.play("hit")
	if is_boss:
		EventBus.boss_damaged.emit(maxf(health, 0.0), max_health)
	if _loom_is_active:
		_update_loom_phase()
	if health <= 0:
		_die()

## §Wave3 织理者阶段推进：HP 阈值不可逆（P1→P2→P3）。
## 切换瞬间广播给 BossBar 显示阶段名，并给一次可读的全屏震动 + 染色。
func _update_loom_phase() -> void:
	if max_health <= 0.0:
		return
	var ratio: float = health / max_health
	var target: int = 1
	if ratio <= 0.33:
		target = 3
	elif ratio <= 0.66:
		target = 2
	if target <= _loom_phase:
		return   # 不可逆，也不回退
	_loom_phase = target
	EventBus.boss_phase_changed.emit(_loom_phase, stats.display_name if stats else "织理者")
	Juice.add_trauma(0.55)
	Juice.haptic(90)
	Sfx.play("hurt", 0.7, -2.0)
	_flash_tint(Color(1.0, 0.55, 0.35) if _loom_phase == 2 else Color(1.0, 0.28, 0.24), 0.3)

func _die() -> void:
	active = false            # 立即停摆，避免后续子弹同帧再触发
	GameState.register_kill(stats.score_value if stats else 10)
	if is_boss:
		GameState.boss_active = false
		Juice.add_trauma(0.95)
		Sfx.play("boss_down")
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
	# 用 _base_scale 而非 spr.scale.x：动画层每帧写 scale，死亡帧可能正好落在压缩相位，
	# 会让爆裂碎片忽大忽小；基准体型才稳定。
	DeathBurst.spawn(get_tree().current_scene, global_position, spr.texture,
		_base_tint, blood, _base_scale.x, stats.scale_mult if stats else 1.0)
	# 变种行为分支（§11.5 M4）：毒雾孢留雾区 / 分裂孢裂出子体
	if stats:
		if stats.behavior == "miasma":
			PoisonCloud.spawn(get_tree().current_scene, global_position,
				stats.poison_radius, stats.poison_duration, stats.poison_dps, blood)
		elif stats.behavior == "split" and not _is_split_child:
			_spawn_splits()
		# Wave 3 新变种死亡残留（§11.14–17）
		elif stats.behavior == "mirror":
			# §11.14 镜影孢：镜面炸裂特效（无特殊掉落，纯粹视觉碎裂）
			pass
		elif stats.behavior == "false_bloom":
			# §11.15 伪孢孢：死亡留下诱饵晶体
			_spawn_false_pickup(global_position)
		elif stats.behavior == "linker":
			# §11.16 链结孢：死亡解除链结对（已在 _die() 前 dissolve 过，但保险起见）
			_dissolve_link()
		elif stats.behavior == "wraith":
			# §11.17 蚀晶孢：死亡时把体内储存的晶体加速吐出来（额外一颗）
			if _wraith_crystal_count > 0:
				_spawn_pickup("crystal", global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)))
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

# ── Wave 3 helper 方法（§11.14–17）──

## §11.16 Linker：注册链结对。由 Spawner/WaveMode 在两只 linker 都 spawn 后调用
func _register_link(partner_id: int, stats_others: EnemyStats) -> bool:
	if _link_partner_id != -1:
		return false   # 已有对家，拒绝二次绑定
	var my_id: int = get_instance_id()
	if _static_links.has(my_id) or _static_links.has(partner_id):
		return false   # 任一方已被其他 linker 占用
	_static_links[my_id] = partner_id
	_static_links[partner_id] = my_id
	_link_partner_id = partner_id
	_update_link_line()   # 立即出线，不等下一帧
	return true

## §11.16 Linker：解除链结对（死亡或池化复用前）。
## 必须同时清掉对家缓存的 _link_partner_id，否则对家会指向一个已经断链的 id。
func _dissolve_link() -> void:
	if _link_partner_id == -1:
		return
	var partner_id: int = _link_partner_id
	_static_links.erase(get_instance_id())
	_static_links.erase(partner_id)
	var partner_node: Node = _find_enemy_by_id(partner_id)
	if partner_node != null and is_instance_valid(partner_node):
		partner_node.set("_link_partner_id", -1)
	_link_partner_id = -1

## §11.16 Linker：把 amount 的一部分转给对家，返回本体实际承受的剩余伤害。
## 对家最多吃自身上限 20%，防一次高伤把对家直接秒掉（读起来也更「分摊」而非「转移」）。
func _split_damage_to_partner(amount: float) -> float:
	var partner_node: Node = _find_enemy_by_id(_link_partner_id)
	if partner_node == null or not is_instance_valid(partner_node):
		return amount
	if not partner_node.has_method("take_damage"):
		return amount
	var ratio: float = stats.link_dmg_share_ratio if stats else 0.5
	var partner_max_hp: float = float(partner_node.get("max_health"))
	var share: float = minf(amount * ratio, partner_max_hp * 0.2)
	if share <= 0.0:
		return amount
	partner_node.set("_link_share_incoming", true)
	partner_node.take_damage(share)
	partner_node.set("_link_share_incoming", false)
	return amount - share

## 根据 instance_id 在 enemy 组里查找对应节点
func _find_enemy_by_id(id: int) -> Node:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get_instance_id() == id:
			return enemy
	return null

## §11.14 Mirror Spore：镜像 burst — 按缓存中的 player 方向射出 2 颗低追踪度弹
func _try_mirror_burst() -> void:
	if _mirror_cache.is_empty():
		return
	var dmg: float = (stats.attack_power if stats else 8.0) * (stats.mirror_bullet_dmg_mult if stats else 0.5)
	var spd: float = (stats.mirror_bullet_speed if stats else 280.0) * WRAITH_BULLET_SPEED_MULT
	Sfx.play("shoot", 1.2, 3.0)
	Juice.add_trauma(0.10)
	for i in 2:
		var dir: Vector2 = _mirror_cache[i % _mirror_cache.size()]
		_spawn_bullet(global_position, dir, dmg, spd, {
			"kind": "needle",
			"lifetime": 1.6,
			"pierce": 0,
		})

## §11.17 Crystal Wraith：计数场上非伪晶体晶体数
func _count_ground_crystals() -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group("pickup"):
		if p.get("kind") == "crystal" and not p.get("_collected"):
			n += 1
	return n

## §11.17 Crystal Wraith：偷取最近一颗未拾取的真晶体（teleport 到其位置并把它吸过来）
func _steal_nearest_crystal() -> void:
	var best: Node2D = null
	var best_dist: float = INF
	for p in get_tree().get_nodes_in_group("pickup"):
		if p.get("kind") != "crystal" or p.get("_collected"):
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < (stats.wraith_steal_range if stats else 200.0) and d < best_dist:
			best = p
			best_dist = d
	if best == null:
		return
	# Wraith teleport 到晶体位置（短距闪现），玩家会看到「晶体被夺走」的视觉反馈
	var from := global_position
	global_position = best.global_position
	velocity = Vector2.ZERO
	# 晶体被偷走：标记为已收集但不实际扣血，只是从玩家视角消失
	best.set_meta("_stolen", true)
	Sfx.play("hit", 0.4, 4.0)
	Juice.add_trauma(0.06)

## §11.15 False Bloom：死亡时在原地 spawn 一颗伪晶体诱饵
func _spawn_false_pickup(pos: Vector2) -> void:
	if not is_instance_valid(PICKUP_SCENE):
		return
	var pk: Node2D = PICKUP_SCENE.instantiate()
	pk.kind = "false"
	pk.fake_hp_penalty = (stats.false_pickup_hp_penalty if stats else 30.0)
	pk.position = pos
	get_tree().current_scene.add_child(pk)
