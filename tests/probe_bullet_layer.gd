extends SceneTree
# 验证：碰撞分层后子弹仍命中敌人（Area2D mask=5：柱子层1 + 敌人层4），
# 且玩家贴身接触伤害照常触发（物理互不阻挡但距离判定保留）。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	var walker = load("res://assets/data/enemy_walker.tres")

	# ---------- 子弹命中：敌人放正前方 120px，开火等命中 ----------
	p.global_position = Vector2.ZERO
	var e: Node2D = pool.acquire(current_scene) as Node2D
	e.configure(walker)
	e.global_position = Vector2(120.0, 0.0)
	e.velocity = Vector2.ZERO   # 定住不动（伏击态外也强制？walker 是常规怪，会追；直接锁血看掉血）
	var hp_before: float = e.health
	var bullet_scene: PackedScene = load("res://scenes/world/Bullet.tscn")
	var b: Area2D = bullet_scene.instantiate()
	b.setup(Vector2.RIGHT, 12.0)
	current_scene.add_child(b)
	b.global_position = p.global_position + Vector2(20.0, 0.0)
	for i in 40:   # 最多 40 物理帧等命中（620px/s × 40帧 ≈ 413px 覆盖 120px 距离）
		await physics_frame
		if e.health < hp_before or not is_instance_valid(e) or not e.active:
			break
	var hit_ok: bool = e.health < hp_before or not e.active
	print("BULLET_HIT hp %.0f -> %.0f ok=%s" % [hp_before, e.health if is_instance_valid(e) else 0.0, hit_ok])

	# ---------- 接触伤害：怪贴脸，冷却后应扣玩家血 ----------
	p.global_position = Vector2(-600.0, -600.0)   # 挪远避开战场中心
	await physics_frame
	var e2: Node2D = pool.acquire(current_scene) as Node2D
	e2.configure(walker)
	e2.global_position = p.global_position + Vector2(20.0, 0.0)   # 贴脸（contact_radius 26 内）
	var php_before: float = p.health
	for i in 90:   # 最多 ~1.5s 等接触判定
		await physics_frame
		if p.health < php_before:
			break
	print("CONTACT_DAMAGE hp %.0f -> %.0f ok=%s" % [php_before, p.health, p.health < php_before])

	var all_ok: bool = hit_ok and p.health < php_before
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
