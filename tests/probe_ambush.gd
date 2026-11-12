extends SceneTree
# 探针：伏击体 Lurker（§11.5 行为分支）。
# 断言：远距潜伏（静止+半透明）→ 玩家进入警觉半径 → 破土 → 高速追击；
# 潜伏期间接触不掉血；被池化复用为杂兵时伏击状态正确清除。
# 注意距离：警觉半径 340，潜伏测试须 > 340（如 500）。

var gs: Node
var player: Node2D

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 15:
		await process_frame
	gs = get_root().get_node_or_null("GameState")
	player = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	if gs == null or player == null or pool == null:
		print("SETUP_FAILED")
		quit()
		return
	gs.start_run()

	var lurker_stats = load("res://assets/data/enemy_lurker.tres")
	var e: Node2D = pool.acquire(current_scene) as Node2D
	e.configure(lurker_stats)
	print("CONFIGURED=", e.stats.display_name)
	# 阶段 1：警觉半径外（500 > 340）→ 保持潜伏
	e.global_position = player.global_position + Vector2(500.0, 0.0)
	await create_timer(0.4, true, false, true).timeout
	print("HIDDEN_STATE=", e._ambush_state)
	print("HIDDEN_ALPHA=", snappedf(e.modulate.a, 0.01))
	print("HIDDEN_STILL=", e.velocity == Vector2.ZERO)

	# 潜伏时不吃接触伤害（把它叠到玩家身上，血量不应变化）
	var hp_before: float = player.health
	e.global_position = player.global_position + Vector2(24.0, 0.0)
	await create_timer(0.3, true, false, true).timeout
	print("NO_DAMAGE_WHILE_HIDDEN=", player.health >= hp_before)

	# 阶段 2：拉开到 400px，再逼近到 300px（进警觉半径）→ 破土
	e.global_position = player.global_position + Vector2(400.0, 0.0)
	await create_timer(0.05, true, false, true).timeout
	e.global_position = player.global_position + Vector2(300.0, 0.0)
	await create_timer(0.2, true, false, true).timeout
	print("EMERGING_STATE=", e._ambush_state)   # 应处于前摇(2)
	await create_timer(0.4, true, false, true).timeout
	print("EMERGED_STATE=", e._ambush_state)    # 应已并入追击(0)
	print("EMERGED_ALPHA=", snappedf(e.modulate.a, 0.01))

	# 阶段 3：拉开 400px → 破土追击速度接近 move_speed 175
	e.global_position = player.global_position + Vector2(400.0, 0.0)
	await create_timer(0.4, true, false, true).timeout
	print("CHASING_SPEED=", snappedf(e.velocity.length(), 0.1))

	# 池化复用：同一实例改配 walker → 伏击状态清零
	var walker_stats = load("res://assets/data/enemy_walker.tres")
	e.configure(walker_stats)
	print("REUSED_AS_WALKER_STATE=", e._ambush_state, " ALPHA=", snappedf(e.modulate.a, 0.01))
	print("OK")
	quit()
