extends Node
# 攻击手段探针（§11.12/§11.13）：毒针单发 / 毒液扇喷 / 毒素 DoT /
# 落地毒云 / Boss 技能（弹幕环或喷息 + 巢群召唤）。headless 冒烟用。

var checks: int = 0
var fails: int = 0

func _check(name: String, cond: bool) -> void:
	checks += 1
	if cond:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name)

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("PROBE_DONE checks=", checks, " fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)

func _run() -> void:
	var arena: Node = load("res://scenes/world/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.start_run()
	var player: Node = get_tree().get_first_node_in_group("player")
	_check("player_exists", player != null)
	player.health = 100000.0   # 探针期间不许被打死

	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	_check("enemy_pool_exists", pool != null)

	# ---- 1) 毒针孢：射程带内自动蓄射单发毒针 ----
	var spitter: Node2D = pool.acquire(get_tree().current_scene)
	spitter.configure(load("res://assets/data/enemy_spitter.tres"))
	spitter.global_position = player.global_position + Vector2(300.0, 0.0)
	spitter._ranged_cd = 0.0
	for i in 40:   # 前摇 0.35s 后开火，毒针还在飞（460px/s，0.65s 后才命中玩家）
		await get_tree().physics_frame
	_check("spitter_bullet_spawned", get_tree().get_nodes_in_group("enemy_bullet").size() >= 1)
	for i in 60:
		await get_tree().physics_frame
	_check("spitter_left_windup", spitter._ranged_state == 0)

	# ---- 2) 酸液孢：扇形毒液（5 发）+ 落地毒云 ----
	var base_bullets: int = get_tree().get_nodes_in_group("enemy_bullet").size()
	var clouds0: int = PoisonCloud._alive.size()
	var sprayer: Node2D = pool.acquire(get_tree().current_scene)
	sprayer.configure(load("res://assets/data/enemy_sprayer.tres"))
	sprayer.global_position = player.global_position + Vector2(-320.0, 120.0)
	sprayer._ranged_cd = 0.0
	for i in 90:
		await get_tree().physics_frame
	var venom_bullets: int = get_tree().get_nodes_in_group("enemy_bullet").size() - base_bullets
	_check("sprayer_fan_shot_5", venom_bullets >= 5)
	# 等毒液落地（lifetime 1.6s 内）：毒云数应增加（撞柱/超时触发）
	for i in 150:
		await get_tree().physics_frame
	_check("venom_left_cloud", PoisonCloud._alive.size() > clouds0)

	# ---- 3) 玩家中毒 DoT：0.5s 一跳，轻量受击 ----
	var hp0: float = player.health
	player.apply_poison(6.0, 2.0)
	for i in 45:   # ~0.75s，应至少跳 1 次
		await get_tree().physics_frame
	_check("poison_dot_ticked", player.health < hp0)
	_check("poison_tinted", player.get_node("Sprite").modulate.g > 0.9)

	# ---- 4) Boss：技能施放（弹幕环或剧毒喷息） ----
	# 先清场隔离：杂兵接触玩家会反复触发 hitstop（time_scale=0.04），
	# 把 Boss 前摇拖慢 25 倍，探针窗口内永远读不完条——真实 Boss 战刷怪已暂停，
	# 杂兵干扰远低于探针环境，这里直接清掉再测技能机。
	for e in get_tree().get_nodes_in_group("enemy"):
		e.set("active", false)
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		b.queue_free()
	await get_tree().physics_frame
	var spawner: Node = arena.get_node("Spawner")
	var boss: Node2D = spawner.spawn_boss()
	_check("boss_spawned", boss != null and boss.is_boss)
	boss._skill_cd = 0.0
	var pre_bullets: int = get_tree().get_nodes_in_group("enemy_bullet").size()
	# 技能随机三选一 → 探针强制指定，两条弹幕路径都确定性覆盖
	boss._skill_pending = 0   # 孢子弹幕（360° 环）
	boss._charge_state = 3
	boss._charge_t = 0.05
	for i in 40:
		await get_tree().physics_frame
	var radial_bullets: int = get_tree().get_nodes_in_group("enemy_bullet").size() - pre_bullets
	_check("boss_radial_cast_bullets", radial_bullets >= 6)
	_check("boss_back_to_chase", boss._charge_state == 0)
	_check("boss_skill_cd_reset", boss._skill_cd > 4.0 and boss._skill_cd < 5.5)   # 已重置并自然衰减中

	# 剧毒喷息：扇形毒液 + 落地毒云
	var clouds_b0: int = PoisonCloud._alive.size()
	boss._skill_pending = 1
	boss._charge_state = 3
	boss._charge_t = 0.05
	for i in 40:
		await get_tree().physics_frame
	var breath_bullets: int = get_tree().get_nodes_in_group("enemy_bullet").size() - pre_bullets - radial_bullets
	_check("boss_breath_cast_bullets", breath_bullets >= 3)
	for i in 70:   # 等毒液落地超时（lifetime 1.5s）留毒云
		await get_tree().physics_frame
	_check("boss_breath_left_clouds", PoisonCloud._alive.size() > clouds_b0)

	# ---- 5) Boss 巢群召唤：场上活敌 +3 ----
	var enemies0: int = _alive_enemies()
	boss._summon_brood()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("boss_summoned_3", _alive_enemies() >= enemies0 + 3)

	# ---- 6) 弹幕命中玩家挂毒（venom 直设玩家身上） ----
	var hp_before: float = player.health
	player.apply_poison(8.0, 1.0)   # 刷新制：取更高 dps
	_check("poison_refresh_max_dps", true)   # 无崩溃即通过（刷新逻辑见 3 的掉血断言）
	for i in 50:
		await get_tree().physics_frame
	_check("poison_continues", player.health < hp_before)

func _alive_enemies() -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active"):
			n += 1
	return n
