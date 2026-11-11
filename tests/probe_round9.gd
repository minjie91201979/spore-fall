extends Node
# 第 9 轮探针：障碍柱系统 + 结算强化
# 1. 障碍柱生成数量 >= 6
# 2. 子弹撞柱销毁（发射瞬间可见 -> 柱前回池 + 分数不变）
# 3. 敌人被柱子隔开时仍能绕行接近玩家（不卡死）
# 4. GameOver 结算面板显示击杀/最高连杀/武器等级

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout   # 等 Arena._ready 完成撒柱
	var arena: Node = get_tree().current_scene
	var player: Node = get_tree().get_first_node_in_group("player")
	var obstacles := get_tree().get_nodes_in_group("obstacle")
	print("PROBE 1 obstacles=%d (need>=6)" % obstacles.size())
	if obstacles.size() < 6 or player == null:
		print("PROBE FAIL setup")
		get_tree().quit(1)
		return

	# 选离所有现役敌人最远的柱子，避免野怪干扰弹道
	var pillar: Node2D = null
	var best_d := -1.0
	for o in obstacles:
		var md := 999999.0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("active"):
				md = minf(md, o.global_position.distance_to(e.global_position))
		if md > best_d:
			best_d = md
			pillar = o

	# --- 2. 子弹撞柱 ---
	var bpool: Node = get_tree().get_first_node_in_group("bullet_pool")
	var score_before: int = GameState.score
	player.global_position = pillar.global_position + Vector2(-300, 0)
	player._last_dir = Vector2.RIGHT
	player.fire()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fired: bool = player._fire_cd > 0.0   # 冷却被置位 = _attack 确实执行过
	print("PROBE 2a fire_cooldown_set=%s" % fired)
	await get_tree().create_timer(0.9).timeout
	var back_hidden := _count_hidden(bpool) == 40
	var score_same: bool = GameState.score == score_before
	print("PROBE 2b bullet_back_in_pool=%s score_unchanged=%s" % [back_hidden, score_same])
	var bullet_ok := fired and back_hidden and score_same

	# --- 3. 敌人绕行（玩家在柱西 300，敌出生在柱东 260，直线被柱挡） ---
	var epool: Node = get_tree().get_first_node_in_group("enemy_pool")
	var walker: Resource = load("res://assets/data/enemy_walker.tres")
	var e: Node2D = epool.acquire(get_tree().current_scene)
	e.configure(walker)
	e.global_position = pillar.global_position + Vector2(260, 0)
	var spawn_pos: Vector2 = e.global_position
	var initial_dist: float = e.global_position.distance_to(player.global_position)
	await get_tree().create_timer(3.0).timeout
	var moved: float = e.global_position.distance_to(spawn_pos)
	var dist_to_player: float = e.global_position.distance_to(player.global_position)
	print("PROBE 3 enemy moved=%.0f dist %0.f -> %.0f (need moved>60 and closer)" % [moved, initial_dist, dist_to_player])
	var avoid_ok := moved > 60.0 and dist_to_player < initial_dist

	# --- 4. 结算面板 ---
	GameState.register_kill()
	GameState.register_kill()
	GameState.register_kill()
	GameState.weapon_level = 4
	GameState.survived_time = 83.0
	GameState.end_run()
	await get_tree().process_frame
	var go: Control = arena.get_node_or_null("UILayer/GameOver")
	var settle_ok := false
	if go:
		var kl: Label = go.get_node("Panel/VBox/KillLabel")
		var cl: Label = go.get_node("Panel/VBox/ComboLabel")
		var wl: Label = go.get_node("Panel/VBox/WeaponLabel")
		var tl: Label = go.get_node("Panel/VBox/TimeLabel")
		print("PROBE 4 visible=%s | %s | %s | %s | %s" % [go.visible, tl.text, kl.text, cl.text, wl.text])
		settle_ok = go.visible and kl.text.contains("3") and cl.text.contains("3") \
			and wl.text.contains("LV4") and tl.text.contains("1:23")

	var all_ok := bullet_ok and avoid_ok and settle_ok
	print("PROBE %s" % ("PASS" if all_ok else "FAIL"))
	get_tree().quit(0 if all_ok else 1)

func _count_hidden(pool: Node) -> int:
	var n := 0
	if pool:
		for c in pool.get_children():
			if c is Node2D and not c.visible:
				n += 1
	return n

func _count_visible(pool: Node) -> int:
	var n := 0
	if pool:
		for c in pool.get_children():
			if c is Node2D and c.visible:
				n += 1
	return n
