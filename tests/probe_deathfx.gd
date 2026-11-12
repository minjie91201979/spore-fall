extends SceneTree
# 验证：① 死亡血水残迹（生成→溅开→存留→自动消失→数量上限）
#        ② 碰撞分层（玩家可穿怪、怪互不叠点、子弹仍能命中、柱子照常阻挡）

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
	var runner = load("res://assets/data/enemy_runner.tres")
	var bp_script = load("res://scripts/fx/BloodPool.gd")

	# ---------- ② 碰撞分层配置断言 ----------
	var ok := true
	ok = ok and p.collision_layer == 2 and p.collision_mask == 1
	var e: Node2D = pool.acquire(current_scene) as Node2D
	e.configure(walker)
	e.global_position = p.global_position + Vector2(60.0, 0.0)
	ok = ok and e.collision_layer == 4 and e.collision_mask == 5
	var bullet_scene: PackedScene = load("res://scenes/world/Bullet.tscn")
	var b := bullet_scene.instantiate()
	ok = ok and b.collision_mask == 5
	b.queue_free()
	print("LAYER_CONFIG ok=", ok)

	# ---------- ② 真物理验证：玩家 mask 查询扫不到重叠敌人 ----------
	await physics_frame
	var space: PhysicsDirectSpaceState2D = current_scene.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	q.shape = shape
	q.transform = Transform2D(0.0, p.global_position)
	q.collision_mask = p.collision_mask   # 玩家实际会撞的东西
	var hits: Array = space.intersect_shape(q, 8)
	var enemy_hit := false
	for h in hits:
		if h.collider == e:
			enemy_hit = true
	print("PLAYER_OVERLAPS_ENEMY=", enemy_hit, " (期望 false = 玩家穿过怪)")

	# ---------- ① 血渍生成 ----------
	var death_pos: Vector2 = e.global_position   # 击杀前记坐标（回池后怪会被挪走）
	e.take_damage(9999.0)   # 击杀 → 应留血渍
	for i in 4:
		await process_frame
	var alive: Array = bp_script._alive
	var spawned_count: int = alive.size()   # 快照（数组是共享引用，之后会被清空）
	print("BLOOD_SPAWNED count=", spawned_count, " (期望 >=1)")
	var found_pos_ok := false
	var found_color_ok := false
	for bp in alive:
		if bp.global_position.distance_to(death_pos) < 8.0:
			found_pos_ok = true
		var c: Color = bp._color
		if absf(c.r - 0.16) < 0.02 and absf(c.g - 0.62) < 0.02 and absf(c.b - 0.55) < 0.02:
			found_color_ok = true
	print("BLOOD_POS_OK=", found_pos_ok, " BLOOD_COLOR_OK=", found_color_ok)

	# ---------- ① 数量上限（杀 60 只，高/中档封顶 50）----------
	for i in 60:
		var w: Node2D = pool.acquire(current_scene) as Node2D
		w.configure(runner)
		w.global_position = Vector2(-800.0 - i * 20.0, -800.0)
		w.take_damage(9999.0)
	for i in 6:
		await process_frame
	print("BLOOD_CAP count=", bp_script._alive.size(), " (期望 <=50)")

	# ---------- ① 自动消失（溅开0.16+存留3.6+淡出1.1 ≈ 4.9s）----------
	await create_timer(6.0, true, false, true).timeout
	print("BLOOD_CLEANED count=", bp_script._alive.size(), " (期望 0)")
	var all_ok: bool = ok and not enemy_hit and spawned_count >= 1 and found_pos_ok \
		and found_color_ok and bp_script._alive.size() <= 50 and bp_script._alive.size() == 0
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
