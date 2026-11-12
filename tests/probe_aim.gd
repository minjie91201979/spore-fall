extends SceneTree
# 验证：① 自动瞄准让走位与开火解耦（含跑动方向加权 / 无目标回退 / 开关回退）
#        ② 全变种移速下调 20%，Boss 冲锋速度保持原量级。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var spawner := current_scene.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)
	var ti = get_root().get_node_or_null("TouchInput")
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	p.global_position = Vector2.ZERO
	p.set_physics_process(false)   # 锁住玩家，避免测试期间自己移动影响距离
	# 清场：开局 Spawner 可能已刷怪，全部停用（active != true 会被自动瞄准跳过）
	for e in get_nodes_in_group("enemy"):
		e.set("active", false)
		e.visible = false
	var walker = load("res://assets/data/enemy_walker.tres")

	# ---------- ① 最近敌人：玩家朝右（_last_dir），怪在左 ----------
	var left: Node2D = pool.acquire(current_scene) as Node2D
	left.configure(walker)
	left.global_position = Vector2(-200.0, 0.0)
	ti.move_vector = Vector2.ZERO
	var aim: Vector2 = p._auto_aim_dir()
	var aim_ok: bool = aim.x < -0.9
	print("AIM_LEFT dir=%s ok=%s" % [aim, aim_ok])

	# 实弹验证：开火方向真的跟着自动瞄准走（不是只改了返回值）
	p._fire_cd = 0.0
	var before := _bullets()
	p.fire()
	var after := _bullets()
	var shot_dir := Vector2.ZERO
	for b in after:
		if not before.has(b):
			shot_dir = b.get("_direction")
			break
	var shot_ok: bool = shot_dir.x < -0.9
	print("BULLET_DIR %s ok=%s" % [shot_dir, shot_ok])

	# ---------- ② 跑动方向加权：右前方 220px 应压过左侧 200px ----------
	var right: Node2D = pool.acquire(current_scene) as Node2D
	right.configure(walker)
	right.global_position = Vector2(220.0, 0.0)
	ti.move_vector = Vector2.RIGHT
	var biased: Vector2 = p._auto_aim_dir()
	var bias_ok: bool = biased.x > 0.9
	print("AIM_BIAS dir=%s ok=%s" % [biased, bias_ok])
	ti.move_vector = Vector2.ZERO

	# ---------- ③ 无目标回退到最后移动方向 ----------
	for e in get_nodes_in_group("enemy"):
		e.set("active", false)
	var empty_aim: Vector2 = p._auto_aim_dir()
	p._fire_cd = 0.0
	var before2 := _bullets()
	p.fire()
	var fallback_dir := Vector2.ZERO
	for b in _bullets():
		if not before2.has(b):
			fallback_dir = b.get("_direction")
			break
	var fallback_ok: bool = empty_aim == Vector2.ZERO and fallback_dir.x > 0.9
	print("NO_TARGET aim=%s bullet=%s ok=%s" % [empty_aim, fallback_dir, fallback_ok])

	# ---------- ④ 关掉自动瞄准回退老手感 ----------
	left.set("active", true)
	ti.auto_aim = false
	p._fire_cd = 0.0
	var before3 := _bullets()
	p.fire()
	var manual_dir := Vector2.ZERO
	for b in _bullets():
		if not before3.has(b):
			manual_dir = b.get("_direction")
			break
	var manual_ok: bool = manual_dir.x > 0.9
	print("MANUAL_MODE bullet=%s ok=%s" % [manual_dir, manual_ok])
	ti.auto_aim = true

	# ---------- ⑤ 速度表 ----------
	var expect := {
		"enemy_walker.tres": 72.0, "enemy_runner.tres": 124.0,
		"enemy_brute.tres": 44.0, "enemy_lurker.tres": 140.0,
		"enemy_miasma.tres": 58.0, "enemy_splitter.tres": 95.0,
		"enemy_boss.tres": 50.0,
	}
	var speed_ok := true
	for fn in expect:
		var s = load("res://assets/data/" + fn)
		if not is_equal_approx(s.move_speed, expect[fn]):
			speed_ok = false
	var boss = load("res://assets/data/enemy_boss.tres")
	var charge_ok: bool = boss.move_speed * boss.charge_speed >= 240.0
	print("SPEEDS ok=%s boss_charge=%.0f ok=%s" % [speed_ok, boss.move_speed * boss.charge_speed, charge_ok])

	var all_ok: bool = aim_ok and shot_ok and bias_ok and fallback_ok and manual_ok and speed_ok and charge_ok
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)

func _bullets() -> Array:
	var out := []
	for c in current_scene.get_children():
		if c is Area2D and c.get("active") == true:
			out.append(c)
	return out
