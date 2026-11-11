extends Node
# 临时冒烟探针：验证对象池开火/命中/回收全链路（跑完请移除 [autoload] 注册）。

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("PROBE FAIL: no player")
		get_tree().quit(1)
		return
	var bpool = get_tree().get_first_node_in_group("bullet_pool")
	var epool = get_tree().get_first_node_in_group("enemy_pool")
	print("PROBE pools: bullet=%s enemy=%s" % [bpool != null, epool != null])
	# 手动放 3 个敌人到玩家右侧一排，保证子弹能命中
	for i in range(3):
		var e = epool.acquire(player.get_parent())
		e.global_position = player.global_position + Vector2(120 + i * 40, 0)
	# 连续开火 20 发：敌人 40 血 / 子弹 12 伤 → 3 个敌人正好 16 发打死，留 4 发余量验证回收
	var fired := 0
	for i in range(20):
		player.fire()
		fired += 1
		await get_tree().physics_frame
	await get_tree().create_timer(1.5).timeout   # 等子弹飞行/命中/回池
	print("PROBE fired=%d score=%d combo=%d" % [fired, GameState.score, GameState.combo])
	# 逐个打印敌人状态，定位击杀链路
	for e in get_tree().get_nodes_in_group("enemy"):
		print("PROBE enemy pos=%s hp=%.1f active=%s visible=%s" % [e.global_position, e.health, e.active, e.visible])
	var player_now = get_tree().get_first_node_in_group("player")
	print("PROBE player hp=%.1f dead=%s running=%s" % [player_now.health, player_now.is_dead, GameState.is_running])
	# 验证池回收：开火后 1.5s，子弹应已回池（free 列表非空或池子节点 hidden）
	var pooled_hidden := 0
	if bpool:
		for c in bpool.get_children():
			if not c.visible:
				pooled_hidden += 1
	print("PROBE bullets_back_in_pool=%d/40" % pooled_hidden)
	var kills3: bool = GameState.combo >= 3
	if kills3 and pooled_hidden >= 40 - 20:
		print("PROBE PASS: pool fire/hit/recycle OK")
		get_tree().quit(0)
	else:
		print("PROBE FAIL: combo=%d pooled_hidden=%d" % [GameState.combo, pooled_hidden])
		get_tree().quit(1)
