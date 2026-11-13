extends SceneTree
# 验证 M4 两个新变种：毒雾孢（死亡雾区+持续伤害+自毁）/ 分裂孢（子体+防递归+池化清理）。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var gs = get_root().get_node_or_null("GameState")
	if gs:
		gs.start_run()
	# 关掉自动刷怪，避免干扰计数与玩家血量
	var spawner := get_first_node_in_group("spawner")
	if spawner:
		spawner.set_process(false)
	var spawner2 := current_scene.get_node_or_null("Spawner")
	if spawner2:
		spawner2.set_process(false)
	var p = get_first_node_in_group("player")
	var pool = get_first_node_in_group("enemy_pool")
	p.global_position = Vector2.ZERO
	var miasma = load("res://assets/data/enemy_miasma.tres")
	var splitter = load("res://assets/data/enemy_splitter.tres")
	var spitter = load("res://assets/data/enemy_spitter.tres")
	var sprayer = load("res://assets/data/enemy_sprayer.tres")
	var pc_script = load("res://scripts/fx/PoisonCloud.gd")

	# ---------- 参数谱接线（8 个杂兵变种，远程两种不再共用别人的脸） ----------
	var variants: Array = spawner2.get("variants") if spawner2 else []
	var spit_path: String = spitter.sprite_texture.resource_path if spitter.sprite_texture else ""
	var spray_path: String = sprayer.sprite_texture.resource_path if sprayer.sprite_texture else ""
	var wired: bool = variants.size() == 8 and miasma.behavior == "miasma" \
		and splitter.behavior == "split" and miasma.sprite_texture != null \
		and splitter.sprite_texture != null \
		and spitter.ranged_attack == "needle" and sprayer.ranged_attack == "venom" \
		and spit_path.ends_with("enemy_spitter.png") \
		and spray_path.ends_with("enemy_sprayer.png") \
		and spitter.sprite_texture != splitter.sprite_texture \
		and sprayer.sprite_texture != miasma.sprite_texture
	print("VARIANTS_WIRED ok=%s count=%d" % [wired, variants.size()])

	# ---------- 毒雾孢：死亡留雾 + 持续伤害 ----------
	var m: Node2D = pool.acquire(current_scene) as Node2D
	m.configure(miasma)
	m.global_position = p.global_position
	var hp0: float = p.health
	m.take_damage(9999.0)
	for i in 3:
		await process_frame
	var clouds: Array = pc_script._alive
	var spawned_clouds: int = clouds.size()   # 快照（静态数组是共享引用，之后会被清空）
	print("POISON_SPAWN count=%d (期望 1)" % spawned_clouds)
	await create_timer(1.6, true, false, true).timeout
	var poisoned: bool = p.health < hp0
	print("POISON_DAMAGE hp %.0f -> %.0f ok=%s" % [hp0, p.health, poisoned])

	# ---------- 分裂孢：生成 2 只子体 ----------
	var s: Node2D = pool.acquire(current_scene) as Node2D
	s.configure(splitter)
	s.global_position = Vector2(320.0, -120.0)
	var normal_scale: float = s.get_node("Sprite").scale.x
	s.take_damage(9999.0)
	for i in 4:
		await process_frame
	var children: Array = []
	for e in get_nodes_in_group("enemy"):
		if e.get("active") and e.get("_is_split_child"):
			children.append(e)
	var child_small: bool = children.size() > 0 \
		and (children[0] as Node2D).get_node("Sprite").scale.x < normal_scale * 0.8
	print("SPLIT children=%d (期望 2) small=%s" % [children.size(), child_small])

	# ---------- 防递归：子体死亡不再分裂 ----------
	var active_before := 0
	for e in get_nodes_in_group("enemy"):
		if e.get("active"):
			active_before += 1
	if children.size() > 0:
		children[0].take_damage(9999.0)
		for i in 4:
			await process_frame
	var active_after := 0
	for e in get_nodes_in_group("enemy"):
		if e.get("active"):
			active_after += 1
	var no_recursion: bool = active_after <= active_before
	print("NO_RECURSION %d -> %d ok=%s" % [active_before, active_after, no_recursion])

	# ---------- 池化清理：回池再取不残留子体标记 ----------
	var fresh: Node2D = pool.acquire(current_scene) as Node2D
	var reuse_clean: bool = not fresh.get("_is_split_child") and is_equal_approx(fresh.get("_size_mult"), 1.0)
	print("REUSE_CLEAN ok=%s" % reuse_clean)

	# ---------- 毒雾自毁（4.0s + 0.9s 淡出 + 余量）----------
	await create_timer(4.6, true, false, true).timeout
	var clouds_left: int = pc_script._alive.size()
	print("POISON_CLEANED count=%d (期望 0)" % clouds_left)

	var all_ok: bool = wired and spawned_clouds >= 1 and poisoned and children.size() == 2 \
		and child_small and no_recursion and reuse_clean and clouds_left == 0
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
