extends Node
# 武器系统探针（临时挂 [autoload] 运行，跑完摘除）。
# 覆盖：初始武器 / 切换 / 各弹种发射 / 燃烧 DoT / 激光穿透 / 武器箱拾取 / 武器栏 UI。
var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("PROBE_WEAPONS_DONE pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _check(name: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name)

func _run() -> void:
	# 启动主场景是标题页：手动实例化 Arena（probe_attacks 同款做法）
	var arena: Node = load("res://scenes/world/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	await get_tree().physics_frame
	GameState.start_run()
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var tctl: Node = arena.get_node("TouchControls")

	# ---- 1) 初始状态：只有沙漠飞鹰 ----
	_check("start_owned_deagle_only", GameState.owned_weapons == ["deagle"])
	_check("start_current_deagle", GameState.current_weapon == "deagle")

	# ---- 2) 武器栏 UI 存在且 5 槽 ----
	var bar: Node = tctl.get_node_or_null("WeaponBar")
	_check("weaponbar_exists", bar != null)
	if bar:
		_check("weaponbar_slots", bar.get_child_count() == 5)

	# ---- 3) 切换霰弹枪：一次开火 6 弹丸 ----
	_check("acquire_shotgun", GameState.acquire_weapon("shotgun"))
	GameState.switch_weapon("shotgun")
	print("DBG current=", GameState.current_weapon, " owned=", GameState.owned_weapons)
	_check("switch_shotgun", GameState.current_weapon == "shotgun")
	player._fire_cd = 0.0
	player.fire()
	await get_tree().physics_frame
	var n_bullets: int = get_tree().get_nodes_in_group("player_bullet").size()
	_check("shotgun_six_pellets", n_bullets >= 6)
	for i in 90:   # 等弹落
		await get_tree().physics_frame

	# ---- 4) 火弹枪：命中点燃敌人 ----
	_check("acquire_firerifle", GameState.acquire_weapon("firerifle"))
	var e1: Node2D = _spawn_enemy(arena, player, Vector2(260.0, 0.0))
	GameState.switch_weapon("firerifle")
	player._fire_cd = 0.0
	player.fire()
	for i in 30:
		await get_tree().physics_frame
		if e1.get("_burn_time") > 0.0:
			break
	_check("firerifle_ignites", is_instance_valid(e1) and float(e1.get("_burn_time")) > 0.0)
	var pre_hp: float = float(e1.get("health"))
	for i in 45:   # 燃烧至少跳 1 次 0.5s tick
		await get_tree().physics_frame
	_check("burn_ticks_damage", not is_instance_valid(e1) or float(e1.get("health")) < pre_hp or e1.get("active") == false)
	if is_instance_valid(e1):
		e1.queue_free()
	for i in 40:
		await get_tree().physics_frame

	# ---- 5) 激光：一条线串两只 ----
	_check("acquire_laser", GameState.acquire_weapon("laser"))
	var e2: Node2D = _spawn_enemy(arena, player, Vector2(300.0, 40.0))
	var e3: Node2D = _spawn_enemy(arena, player, Vector2(300.0, 48.0))
	# 冻结两靶：敌人会继续走位，导致激光命中后第二靶早已偏离弹道
	e2.set_physics_process(false)
	e3.set_physics_process(false)
	# 隔离：停掉刷怪器与其它杂兵，保证自动瞄准只能锁定 e2/e3
	arena.get_node("Spawner").set_physics_process(false)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != e2 and e != e3 and e.get("active") == true:
			e.set("active", false)
	for i in 5:
		await get_tree().physics_frame
	var hp2: float = float(e2.get("health"))
	var hp3: float = float(e3.get("health"))
	GameState.switch_weapon("laser")
	player._fire_cd = 0.0
	player.fire()
	await get_tree().physics_frame
	var lb := get_tree().get_nodes_in_group("player_bullet")
	print("DBG laser bullets=", lb.size(), " aim_dir_ok=", lb.size() > 0)
	for b in lb:
		if b.active:
			print("DBG pos=", b.global_position, " dir=", b._direction, " pierce=", b.pierce_left, " kind=", b.bullet_kind)
	for i in 40:
		await get_tree().physics_frame
	var hit2: bool = not is_instance_valid(e2) or float(e2.get("health")) < hp2
	var hit3: bool = not is_instance_valid(e3) or float(e3.get("health")) < hp3
	print("DBG hp2 ", hp2, "->", e2.get("health") if is_instance_valid(e2) else -1.0,
		" hp3 ", hp3, "->", e3.get("health") if is_instance_valid(e3) else -1.0)
	_check("laser_pierces_both", hit2 and hit3)
	# 激光寿命 2.8s，直接回收所有在飞子弹验证回池路径
	for b in get_tree().get_nodes_in_group("player_bullet"):
		b._release()
	await get_tree().physics_frame
	_check("laser_bullet_gone", get_tree().get_nodes_in_group("player_bullet").size() == 0)
	for n in [e2, e3]:
		if is_instance_valid(n):
			n.queue_free()
	for i in 30:
		await get_tree().physics_frame

	# ---- 6) 武器箱拾取：拿新枪并自动切换 ----
	var pack_scene: PackedScene = load("res://scenes/world/Pickup.tscn")
	var pk: Node2D = pack_scene.instantiate()
	pk.kind = "weapon"
	pk.weapon_id = "flamethrower"
	arena.add_child(pk)
	pk.global_position = player.global_position + Vector2(0.0, -6.0)
	for i in 20:
		await get_tree().physics_frame
		if GameState.owned_weapons.has("flamethrower"):
			break
	_check("pickup_grants_weapon", GameState.owned_weapons.has("flamethrower"))
	_check("pickup_autoswitch", GameState.current_weapon == "flamethrower")
	_check("owned_sorted", GameState.owned_weapons == ["deagle", "shotgun", "firerifle", "flamethrower", "laser"])

	# ---- 7) 喷火枪发射：短命火舌 ----
	player._fire_cd = 0.0
	player.fire()
	await get_tree().physics_frame
	var flame_alive: int = get_tree().get_nodes_in_group("player_bullet").size()
	_check("flame_fires", flame_alive >= 1)

	# ---- 8) 重复拾取同武器被拒绝（背包不重复、不掉格子） ----
	var owned_before: int = GameState.owned_weapons.size()
	var res: bool = GameState.acquire_weapon("flamethrower")   # 已拥有 → false
	_check("acquire_dup_rejected", res == false and GameState.owned_weapons.size() == owned_before)

func _spawn_enemy(arena: Node, player: Node2D, offset: Vector2) -> Node2D:
	var scene: PackedScene = load("res://scenes/world/Enemy.tscn")
	var e: Node2D = scene.instantiate()
	arena.add_child(e)
	e.configure(load("res://assets/data/enemy_walker.tres"))
	e.global_position = player.global_position + offset
	e.active = true
	return e
