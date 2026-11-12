extends SceneTree
# 验证：被打爆演出（阶段A闪白膨胀 → 阶段B碎片四散 → 自毁）、参数传递、封顶、Boss 强化。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	var pool = get_first_node_in_group("enemy_pool")
	var walker = load("res://assets/data/enemy_walker.tres")
	var boss = load("res://assets/data/enemy_boss.tres")
	var db_script = load("res://scripts/fx/DeathBurst.gd")

	# ---------- 生成 + 阶段A ----------
	var e: Node2D = pool.acquire(current_scene) as Node2D
	e.configure(walker)
	e.global_position = Vector2(240.0, 120.0)
	var death_pos: Vector2 = e.global_position
	var tex: Texture2D = e.get_node("Sprite").texture
	e.take_damage(9999.0)
	await process_frame
	await process_frame
	var alive: Array = db_script._alive
	var spawned: int = alive.size()
	var d = alive[0] if spawned > 0 else null
	var a_ok: bool = spawned >= 1 and d != null and d._t < d.POP_TIME \
		and d._tex == tex and d.global_position.distance_to(death_pos) < 2.0 \
		and d._tint == walker.tint and d._spr_scale > 0.0
	var shard_count: int = d._shards.size() if d != null else 0
	print("STAGE_A ok=%s spawned=%d shards=%d t=%.3f" % [a_ok, spawned, shard_count, d._t if d != null else -1.0])

	# ---------- 阶段B：碎片确实飞散 ----------
	await create_timer(0.22, true, false, true).timeout
	var b_ok := false
	if is_instance_valid(d):
		var moved := false
		for sh in d._shards:
			if sh.pos.length() > 4.0:
				moved = true
				break
		b_ok = d._t > d.POP_TIME and moved
		print("STAGE_B ok=%s t=%.3f" % [b_ok, d._t])
	else:
		print("STAGE_B ok=false (替身过早消失)")

	# ---------- 自毁 ----------
	await create_timer(0.9, true, false, true).timeout
	var cleaned: int = db_script._alive.size()
	print("CLEANED count=%d (期望 0)" % cleaned)

	# ---------- Boss 强化 + 同屏封顶 ----------
	var be: Node2D = pool.acquire(current_scene) as Node2D
	be.configure(boss)
	be.global_position = Vector2(-600.0, -600.0)
	be.take_damage(999999.0)
	await process_frame
	var boss_shards: int = 0
	for x in db_script._alive:
		if x._size_mult > 2.0:
			boss_shards = x._shards.size()
			break
	for i in 30:
		var w: Node2D = pool.acquire(current_scene) as Node2D
		w.configure(walker)
		w.global_position = Vector2(-800.0 - i * 22.0, -800.0)
		w.take_damage(9999.0)
	for i in 4:
		await process_frame
	var capped: int = db_script._alive.size()
	print("BOSS_SHARDS=%d (期望 >%d) CAP=%d (期望 <=24)" % [boss_shards, shard_count, capped])

	var all_ok: bool = a_ok and b_ok and cleaned == 0 and boss_shards > shard_count and capped <= 24
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
