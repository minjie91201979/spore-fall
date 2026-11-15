extends SceneTree
# 补强探针：覆盖 probe_wave.gd 为了「跳过等待」而置 0 从未真正驱动过的三条分支。
#
# probe_wave.gd 把 wave1_delay / wave2_delay 都设成 0 让链路能跑完，代价是：
#   - 45s 铺垫期计时逻辑（_wave1_t 累加到点自动 _start_wave1）从未被执行；
#   - 6s 分批增援（_wave2_reinforce）从未被触发；
#   - 提高后的刷怪权重是否真让新怪成为第二波主力，只验了数值没验分布；
#   - 波次目标文案在生存模式 HUD 上是否真的可见，只验了 GameState 字符串。
#
# 手法：headless 单帧 delta 极小、靠墙钟等不完 45s，所以不硬等——直接把内部
# 计时器 set 到阈值前一点，再让真实的 _process() 走完剩余一点点，触发真实分支。

var gs: Node
var passc: int = 0
var failc: int = 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	await _frames(15)
	gs = get_root().get_node_or_null("GameState")
	_check(gs != null, "GAMESTATE_FOUND")
	if gs == null:
		_fail_exit()
		return
	var wm: Node = current_scene.get_node_or_null("WaveMode")
	_check(wm != null, "WAVEMODE_FOUND")
	if wm == null:
		_fail_exit()
		return

	# ---------- 1. 铺垫期：计时驱动 + HUD 文案可见 ----------
	var d1: float = float(wm.get("wave1_delay"))
	_check(int(wm.get("_wave")) == 0, "WARMUP_WAVE0")
	_check(d1 >= 20.0, "WARMUP_DELAY(%ds)" % int(d1))
	_check(_find_boss("母巢孢") == null, "WARMUP_NO_BOSS_YET")
	var obj: String = gs.objective_text
	_check("清剿孢群" in obj and "苏醒" in obj, "WARMUP_OBJECTIVE(%s)" % obj)
	# HUD 目标栏：生存模式此前被 `story and ...` 挡住，玩家看不到任何波次提示
	var hud: Node = current_scene.get_node_or_null("UILayer/HUD")
	if hud:
		var ol: Node = hud.get_node_or_null("ObjectiveLabel")
		_check(ol != null, "HUD_OBJECTIVE_NODE")
		if ol:
			_check(bool(ol.get("visible")), "HUD_OBJECTIVE_VISIBLE_IN_SURVIVAL")
			_check(ol.get("position").y > 200.0, "HUD_OBJECTIVE_NO_OVERLAP")
	else:
		_fail("HUD_NODE_MISSING")

	# 把铺垫计时器推到阈值前，让真实 _process 走完最后一点触发 _start_wave1()
	wm.set("_wave1_t", d1 - 0.0001)
	await _frames(6)
	_check(int(wm.get("_wave")) == 1, "WARMUP_ELAPSED_AUTO_WAVE1")
	_check("击溃母巢孢" in gs.objective_text, "WAVE1_OBJECTIVE_SET")
	_check(_find_boss("母巢孢") != null, "WARMUP_ELAPSED_BOSS_SPAWNED")

	# ---------- 2. 进入第二波（复用既有链路） ----------
	var boss1 := _find_boss("母巢孢")
	if boss1:
		boss1.take_damage(boss1.max_health + 1.0)
	await _frames(12)
	var card: Node = current_scene.get_node_or_null("UILayer/WaveCard")
	if card and bool(card.get("active")):
		card._on_continue()
	await _frames(12)
	_check(int(wm.get("_wave")) == 2, "WAVE2_ENTERED")
	_check(bool(wm.get("_wave2_started")), "WAVE2_TIMER_RUNNING")
	_check(not bool(wm.get("_reinforced")), "REINFORCE_NOT_YET")
	var before_reinforce := _new_monster_count()

	# ---------- 3. 分批增援：此前从未被真正触发过的分支 ----------
	var ra: float = float(wm.get("reinforce_at"))
	var d2: float = float(wm.get("wave2_delay"))
	_check(ra < d2, "REINFORCE_BEFORE_BOSS")
	wm.set("_wave2_t", ra - 0.0001)
	await _frames(6)
	_check(bool(wm.get("_reinforced")), "REINFORCE_TRIGGERED")
	var after_reinforce := _new_monster_count()
	_check(after_reinforce > before_reinforce, "REINFORCE_ADDS_MOBS(%d->%d)" % [before_reinforce, after_reinforce])
	_check(_find_boss("渊噬孢") == null, "REINFORCE_NOT_BOSS_YET")

	# ---------- 4. 权重分布：新怪是不是真的成了第二波主力 ----------
	var spawner: Node = current_scene.get_node_or_null("Spawner")
	if spawner:
		var ratio := _sample_new_ratio(spawner, 1200)
		_check(ratio > 0.35, "WAVE2_NEW_MOB_RATIO(%.1f%%)" % (ratio * 100.0))
	else:
		_fail("SPAWNER_MISSING")

	# ---------- 5. 到点召唤渊噬孢 ----------
	wm.set("_wave2_t", d2 - 0.0001)
	await _frames(6)
	_check(_find_boss("渊噬孢") != null, "WAVE2_BOSS_ON_TIME")

	print("WAVE_TIMING_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

func _sample_new_ratio(spawner: Node, n: int) -> float:
	# 直接调 _pick_variant() 采样（GDScript 无强制 private），统计三只新怪占比。
	var hit := 0
	for i in n:
		var st = spawner._pick_variant()
		if st == null:
			continue
		var nm: String = st.get("display_name")
		if "Corroder" in nm or "Burrower" in nm or "Bloom" in nm:
			hit += 1
	return float(hit) / float(n)

func _new_monster_count() -> int:
	var c := 0
	for e in get_nodes_in_group("enemy"):
		if not bool(e.get("active")) or bool(e.get("is_boss")):
			continue
		c += 1
	return c

func _find_boss(substr: String) -> Node:
	for e in get_nodes_in_group("boss"):
		if not bool(e.get("active")):
			continue
		var st = e.get("stats")
		if st and substr in st.get("display_name"):
			return e
	return null

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1
		print("PASS ", label)
	else:
		_fail(label)

func _fail(label: String) -> void:
	failc += 1
	print("FAIL ", label)

func _fail_exit() -> void:
	print("WAVE_TIMING_PASS=%d FAIL=%d" % [passc, failc])
	print("FAILED")
	quit()
