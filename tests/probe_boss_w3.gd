extends SceneTree
# 方案B 验收：织理者完整机制（docs/wave3-boss-state-machine.md §六 DoD 14 项）
# 覆盖：阶段时序 / 技能冷却互斥 / HP 阈值 / 反射柱 teleport / 幻影免伤+自毁掉晶体 /
#       覆写协议冻结与解冻 / P3 伪晶体密度×4 / 织线 spawn-收缩-消失 / 死亡清理无残留

var gs: Node
var bus: Node
var boss: Node
var passc: int = 0
var failc: int = 0

func _initialize() -> void:
	Engine.time_scale = 6.0   # 加速计时器类断言（2s 自毁 / 3s 解冻），逻辑不受影响
	change_scene_to_file("res://scenes/world/Arena.tscn")
	await _frames(15)
	gs = get_root().get_node_or_null("GameState")
	bus = get_root().get_node_or_null("EventBus")
	if gs and not gs.is_running:
		gs.start_run()

	boss = _spawn_loom()
	_check(boss != null, "D01_LOOM_SPAWNABLE")
	if boss == null:
		_fail_exit(); return
	if bus:
		bus.emit_signal("boss_spawned", boss.stats.display_name, boss.max_health)
	await _frames(2)

	var max_hp: float = boss.max_health

	# --- D01 阶段系统激活 / P1 起始 ---
	_check(boss._loom_is_active and boss._loom_phase == 1, "D01_PHASE_SYSTEM_P1")

	# --- D02 P1 技能池无克隆(3)/覆写(4)：冷却互斥 ---
	var p1_pool: Array[int] = []
	for i in 60:
		boss._begin_skill(200.0)
		p1_pool.append(boss._skill_pending)
		boss._charge_state = 0
	_check(not p1_pool.has(3) and not p1_pool.has(4), "D02_P1_SKILLS_NO_CLONE_REWRITE(%s)" % str(p1_pool))

	# --- D03 HP 66% 切 P2 + 反射柱 ×3 + 织线 spawn ---
	boss.take_damage(max_hp * 0.35)
	await _frames(3)
	_check(boss._loom_phase == 2, "D03_SWITCH_P2_AT_66PCT")
	var pillars: Array = get_nodes_in_group("loom_pillar")
	_check(pillars.size() == 3, "D03_PILLARS_SPAWNED(%d)" % pillars.size())
	var threads: Array = get_nodes_in_group("loom_thread")
	_check(threads.size() >= 2, "D03_THREADS_SPAWNED_P2(%d)" % threads.size())

	# --- D04 反射柱 teleport 玩家到对映点 ---
	if pillars.size() > 0:
		var pillar: Node2D = pillars[0] as Node2D
		var pl: Node2D = get_first_node_in_group("player")
		if pl:
			pl.set_meta("loom_teleported", false)
			pl.global_position = pillar.global_position + Vector2(45.0, 0.0)
			var before: Vector2 = pl.global_position
			var expect: Vector2 = 2.0 * pillar.global_position - before
			pillar.call("_on_body_entered", pl)
			await _frames(2)
			var after: Vector2 = pl.global_position
			_check(bool(pl.get_meta("loom_teleported", false)), "D04_PLAYER_TELEPORTED_FLAG")
			_check(after.distance_to(expect) < 6.0, "D04_TELEPORT_TO_MIRROR(dist=%.1f)" % after.distance_to(expect))
		else:
			_check(false, "D04_PLAYER_EXISTS")
	else:
		_check(false, "D04_PILLAR_EXISTS")

	# --- D05 P2 技能池含克隆(3)不含覆写(4) ---
	var p2_pool: Array[int] = []
	for i in 60:
		boss._begin_skill(200.0)
		p2_pool.append(boss._skill_pending)
		boss._charge_state = 0
	_check(p2_pool.has(3) and not p2_pool.has(4), "D05_P2_POOL_CLONE_ONLY(%s)" % str(p2_pool))

	# --- D06 克隆降临：幻影免伤 + 2s 自毁掉伪晶体 ---
	var false_before: int = _count_false_crystals()
	boss._spawn_loom_clones(3)
	await _frames(2)
	var clones: Array = _find_clones()
	_check(clones.size() == 3, "D06_CLONES_SPAWNED(%d)" % clones.size())
	if clones.size() > 0:
		var c: Node = clones[0]
		var was_active: bool = bool(c.get("active"))
		c.call("take_damage", 9999.0)
		await _frames(1)
		_check(was_active and bool(c.get("active")) and is_instance_valid(c), "D06_CLONE_IMMUNE_TO_DAMAGE")
	# 等 2s 自毁（time_scale 6 下约 0.35s 真实时间）
	await _frames(40)
	var false_after: int = _count_false_crystals()
	_check(false_after >= false_before + 3, "D06_CLONES_DROP_FALSE_CRYSTALS(%d->%d)" % [false_before, false_after])
	_check(_find_clones().is_empty(), "D06_CLONES_DISSOLVED")

	# --- D07 HP 33% 切 P3 + 反射柱转红(phase=3) ---
	boss.take_damage(max_hp * 0.32)
	await _frames(3)
	_check(boss._loom_phase == 3, "D07_SWITCH_P3_AT_33PCT")
	var all_red: bool = true
	for p in pillars:
		if is_instance_valid(p) and int(p.get("_phase")) != 3:
			all_red = false
	_check(all_red, "D07_PILLARS_RED_IN_P3")

	# --- D08 P3 技能池含覆写(4) ---
	var p3_pool: Array[int] = []
	for i in 80:
		boss._begin_skill(200.0)
		p3_pool.append(boss._skill_pending)
		boss._charge_state = 0
	_check(p3_pool.has(4), "D08_P3_POOL_HAS_REWRITE(%s)" % str(p3_pool))

	# --- D09 覆写协议：冻结全场 pickup ---
	gs.pickup_frozen = false
	boss._execute_rewrite_protocol()
	await _frames(2)
	_check(bool(gs.pickup_frozen), "D09_REWRITE_FREEZES_PICKUPS")

	# --- D10 3s 后自动解冻 ---
	await _frames(60)   # time_scale 6：60 帧约 1s 真实 = 6s 逻辑，足够 3s 到期
	_check(not bool(gs.pickup_frozen), "D10_REWRITE_UNFREEZES_AFTER_3S")

	# --- D11 P3 伪晶体密度 ×4（短时间 ≥10）---
	var before_density: int = _count_false_crystals()
	for i in 4:
		boss._loom_false_burst_t = 0.0
		boss._tick_loom_p3_field(0.0)
	await _frames(2)
	var after_density: int = _count_false_crystals()
	_check(after_density - before_density >= 12, "D11_P3_FALSE_CRYSTAL_DENSITY(%d->%d)" % [before_density, after_density])

	# --- D12 织线收缩后消失 + 消失点掉伪晶体 ---
	var t: Node = get_first_node_in_group("loom_thread")
	if t:
		var fb: int = _count_false_crystals()
		t.set("_start", Vector2.ZERO)
		t.set("_end", Vector2(61.0, 0.0))   # 略大于 MIN_LEN=60，下一帧收缩即触发消失
		await _frames(4)
		_check(not is_instance_valid(t), "D12_THREAD_VANISHES")
		_check(_count_false_crystals() >= fb, "D12_THREAD_DROPS_CRYSTAL(%d->%d)" % [fb, _count_false_crystals()])
	else:
		_check(false, "D12_THREAD_EXISTS")

	# --- D13 阶段不可逆：P3 回血不退回 ---
	boss.health = max_hp * 0.95
	boss._update_loom_phase()
	_check(boss._loom_phase == 3, "D13_PHASE_IRREVERSIBLE")

	# --- D14 死亡清理：反射柱/织线/冻结全清，无状态残留 ---
	gs.pickup_frozen = true
	boss.health = 1.0
	boss.take_damage(10.0)
	await _frames(4)
	_check(get_nodes_in_group("loom_pillar").is_empty(), "D14_PILLARS_CLEARED_ON_DEATH")
	_check(get_nodes_in_group("loom_thread").is_empty(), "D14_THREADS_CLEARED_ON_DEATH")
	_check(not bool(gs.pickup_frozen), "D14_FREEZE_CLEARED_ON_DEATH")
	_check(boss._loom_effect_nodes.is_empty(), "D14_EFFECT_LIST_EMPTY")

	Engine.time_scale = 1.0
	print("BOSS_W3_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

# ---------- helpers ----------
func _spawn_loom() -> Node:
	var pool: Node = get_first_node_in_group("enemy_pool")
	if pool == null:
		return null
	var e: Node = pool.acquire(current_scene)
	if e == null:
		return null
	e.configure(load("res://assets/data/enemy_loomweaver.tres"))
	var pl: Node = get_first_node_in_group("player")
	e.global_position = (pl.global_position if pl else Vector2.ZERO) + Vector2(300, 0)
	return e

func _count_false_crystals() -> int:
	var n: int = 0
	for p in get_nodes_in_group("pickup"):
		if p.get("kind") == "false" and not p.get("_collected"):
			n += 1
	return n

# 幻影用 LoomClone.gd：通过脚本路径识别（不加入 enemy 组，避免混淆）
func _find_clones() -> Array:
	var out: Array = []
	for n in current_scene.get_children():
		var s: Script = n.get_script() as Script
		if s and s.resource_path.ends_with("LoomClone.gd"):
			out.append(n)
	return out

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1; print("PASS ", label)
	else:
		failc += 1; print("FAIL ", label)

func _fail_exit() -> void:
	Engine.time_scale = 1.0
	print("BOSS_W3_PASS=%d FAIL=%d" % [passc, failc])
	print("FAILED")
	quit()
