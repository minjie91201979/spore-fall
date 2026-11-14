extends SceneTree
# 探针：第二波（深巢反扑）端到端流转断言。
# 第一波 BOSS（母巢孢）击溃 → WaveCard 暂停弹出 → 继续 → 第二波注入三新怪 + 召唤渊噬孢 → 击溃。
# 注：--script 入口在 Autoload 注册前编译，单例须运行时 get_root().get_node() 取。

var gs: Node
var passc: int = 0
var failc: int = 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	await _frames(15)
	gs = get_root().get_node_or_null("GameState")
	_check(gs != null, "GAMESTATE_FOUND")
	if gs == null:
		quit()
		return
	if not gs.is_running:
		gs.start_run()
	await _frames(30)   # 等 WaveMode 发起第一波 BOSS

	# ---- 第一波 BOSS ----
	var boss1 := _find_active_boss("母巢孢")
	_check(boss1 != null, "WAVE1_BOSS_SPAWNED")
	if boss1 == null:
		_fail_exit()
		return
	_check(boss1.is_boss, "WAVE1_IS_BOSS")
	_check(gs.boss_active, "WAVE1_BOSS_ACTIVE")
	_check(gs.bosses_spawned >= 1, "BOSSES_SPAWNED_GE1")

	# ---- 击溃第一波 BOSS → 应弹出 WaveCard（暂停） ----
	boss1.take_damage(boss1.max_health + 1)
	await _frames(20)
	var card: Node = current_scene.get_node_or_null("UILayer/WaveCard")
	_check(card != null, "WAVECARD_NODE_EXISTS")
	_check(paused, "TREE_PAUSED_FOR_CARD")
	if card:
		_check(card.get("active"), "WAVECARD_ACTIVE")

	# ---- 继续 → 第二波 ----
	if card:
		card._on_continue()
	await _frames(20)
	_check(not paused, "TREE_RESUMED")
	var wm: Node = current_scene.get_node_or_null("WaveMode")
	_check(wm != null, "WAVEMODE_EXISTS")
	if wm:
		_check(int(wm.get("_wave")) == 2, "WAVE_NOW_2")
	var spawner: Node = current_scene.get_node_or_null("Spawner")
	if spawner:
		_check(spawner.variants.size() >= 11, "SPAWNER_HAS_3_NEW_VARIANTS(%d)" % spawner.variants.size())
	# 第二波应立即刷出三只新怪
	var new_names := _active_new_monster_count()
	_check(new_names >= 3, "WAVE2_IMMEDIATE_SPAWN(%d)" % new_names)

	# ---- 召唤第二波 BOSS（渊噬孢） ----
	# headless 帧不受 vsync 约束，单帧 delta 极小，靠墙钟累计 wave2_delay 不可靠；
	# 直接把延迟设为 0，让下一个 _process 帧走真实的 _spawn_boss(ABYSS) 分支。
	if wm:
		wm.set("wave2_delay", 0.0)
	await _frames(20)
	var boss2 := _find_active_boss("渊噬孢")
	_check(boss2 != null, "WAVE2_BOSS_SPAWNED")
	if boss2 == null:
		_fail_exit()
		return
	_check(boss2.max_health > 4000.0, "WAVE2_BOSS_HP(%d)" % int(boss2.max_health))
	_check(gs.boss_active, "WAVE2_BOSS_ACTIVE")

	# ---- 击溃第二波 BOSS → 区域肃清 ----
	boss2.take_damage(boss2.max_health + 1)
	await _frames(20)
	_check(not gs.boss_active, "WAVE2_BOSS_DOWN")
	_check("区域已肃清" in gs.objective_text, "OBJECTIVE_CLEARED(%s)" % gs.objective_text)

	print("WAVE_FLOW_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

func _find_active_boss(substr: String) -> Node:
	for e in get_nodes_in_group("boss"):
		if not e.get("active"):
			continue
		var st = e.get("stats")
		if st and substr in st.display_name:
			return e
	return null

func _active_new_monster_count() -> int:
	var names := {}
	for e in get_nodes_in_group("enemy"):
		if not e.get("active"):
			continue
		var st = e.get("stats")
		if st and ("Corroder" in st.display_name or "Burrower" in st.display_name or "Bloom" in st.display_name):
			names[st.display_name] = true
	return names.size()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1
		print("PASS ", label)
	else:
		failc += 1
		print("FAIL ", label)

func _fail_exit() -> void:
	print("WAVE_FLOW_PASS=%d FAIL=%d" % [passc, failc])
	print("FAILED")
	quit()
