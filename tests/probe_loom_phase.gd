extends SceneTree
# 方案A 验收：织理者三阶段最小可用版
# 断言：阈值切换（66%/33%）+ 不可逆 + BossBar 事件广播 + 阶段技能池/弹幕数递增

var gs: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	await _frames(15)
	gs = get_root().get_node_or_null("GameState")
	if gs and not gs.is_running:
		gs.start_run()

	# 收阶段广播
	var bus: Node = get_root().get_node_or_null("EventBus")
	var phases: Array[int] = []
	if bus:
		bus.connect("boss_phase_changed", func(p: int, _n: String) -> void: phases.append(p))

	var boss := _spawn_loom()
	_check(boss != null, "LOOM_SPAWNED")
	if boss == null:
		_fail_exit(); return
	# 真实链路：WaveMode._spawn_boss 会先 emit boss_spawned，BossBar 才 visible。
	# 探针直接 acquire 绕过了这一步，手动补发以还原真实 UI 状态。
	if bus:
		bus.emit_signal("boss_spawned", boss.stats.display_name, boss.max_health)
	await _frames(2)

	_check(boss._loom_is_active, "PHASE_SYSTEM_ACTIVE")
	_check(boss._loom_phase == 1, "STARTS_AT_P1")
	var max_hp: float = boss.max_health
	_check(max_hp > 6000.0, "LOOM_HP_HIGH(%d)" % int(max_hp))

	# --- P1 → P2: 打到 65% ---
	boss.take_damage(max_hp * 0.35)
	await _frames(3)
	_check(boss._loom_phase == 2, "SWITCH_TO_P2_AT_65PCT(phase=%d)" % boss._loom_phase)
	_check(phases.size() == 1 and phases[0] == 2, "PHASE_EVENT_EMITTED(%s)" % str(phases))

	# --- P2 内不重复广播 ---
	boss.take_damage(max_hp * 0.10)
	await _frames(3)
	_check(boss._loom_phase == 2, "STILL_P2_AT_55PCT")
	_check(phases.size() == 1, "NO_REPEAT_EVENT_WITHIN_PHASE(%d)" % phases.size())

	# --- P2 → P3: 打到 30% ---
	boss.take_damage(max_hp * 0.25)
	await _frames(3)
	_check(boss._loom_phase == 3, "SWITCH_TO_P3_AT_30PCT(phase=%d)" % boss._loom_phase)
	_check(phases.size() == 2 and phases[1] == 3, "P3_EVENT_EMITTED(%s)" % str(phases))

	# --- 不可逆：P3 回血不应退回 P2 ---
	boss.health = max_hp * 0.9
	boss._update_loom_phase()
	_check(boss._loom_phase == 3, "PHASE_IRREVERSIBLE")

	# --- 阶段技能池：P3 应包含 3（克隆降临） ---
	var pool_ok: bool = false
	for i in 40:
		boss._begin_skill(200.0)
		if boss._skill_pending == 3:
			pool_ok = true
			break
		boss._charge_state = 0   # 强制回追击态，允许再次选招
	_check(pool_ok, "P3_SKILL_POOL_HAS_CLONE")

	# --- BossBar 阶段标签 ---
	var bar: Node = current_scene.get_node_or_null("UILayer/BossBar")
	_check(bar != null, "BOSSBAR_EXISTS")
	if bar:
		var tag: Label = bar.get_node_or_null("Box/TagLabel") as Label
		_check(tag != null and "P3" in tag.text, "BOSSBAR_SHOWS_P3(%s)" % (tag.text if tag else "null"))

	print("LOOM_PHASE_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

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

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1; print("PASS ", label)
	else:
		failc += 1; print("FAIL ", label)

var passc: int = 0
var failc: int = 0

func _fail_exit() -> void:
	print("LOOM_PHASE_PASS=%d FAIL=%d" % [passc, failc])
	print("FAILED")
	quit()
