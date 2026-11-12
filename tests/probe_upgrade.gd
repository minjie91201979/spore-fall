extends SceneTree
# 验证：局内三选一升级卡（§11.11）全链路
#   卡池抽卡 / 稀疏升级点 / 暂停开卡 / 点击与键盘 / mods 乘区 /
#   Player 重算 / Bullet 弹速射程穿透 / Pickup 磁吸 / HUD 接线 / 重开重置 / 结算兜底
# 用临时存档路径，绝不污染玩家真实的 save.cfg / career.cfg。

class FakeEnemy:
	extends Node2D
	var taken: float = 0.0
	func take_damage(d: float) -> void:
		taken += d

var gs: Node
var failed: Array[String] = []

func _ck(tag: String, ok: bool, extra: String = "") -> void:
	print("%s ok=%s %s" % [tag, ok, extra])
	if not ok:
		failed.append(tag)

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	gs = get_root().get_node_or_null("GameState")
	var career = get_root().get_node_or_null("Career")
	gs.save_path = "user://save_upgrade_probe.cfg"
	career.save_path = "user://career_upgrade_probe.cfg"
	var root: Node = current_scene
	var ui: Control = root.get_node_or_null("UILayer/UpgradeUI")
	var player: Node = root.get_node_or_null("Player")
	var hud: Control = root.get_node_or_null("UILayer/HUD")
	var tc: Node = root.get_node_or_null("TouchControls")
	var spawner: Node = root.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)

	# ---------- 1. 卡池 ----------
	var picked: Array = UpgradePool.pick({}, 3)
	var ids: Array = []
	for c in picked:
		ids.append(c.id)
	var uniq: bool = ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]
	var capped: Dictionary = {"fire_rate": 99}
	var never_capped: bool = true
	for i in 10:
		for c in UpgradePool.pick(capped, 3):
			if c.id == "fire_rate":
				never_capped = false
	var all_maxed: Dictionary = {}
	for c in UpgradePool.CARDS:
		all_maxed[c.id] = UpgradePool.max_taken(c.id)
	var empty_when_full: bool = UpgradePool.pick(all_maxed, 3).is_empty()
	var byid_ok: bool = UpgradePool.by_id("pierce").name == "贯穿孢针" \
		and UpgradePool.by_id("nope").is_empty()
	_ck("POOL", uniq and never_capped and empty_when_full and byid_ok,
		"ids=%s" % str(ids))

	# ---------- 2. 初始 mods ----------
	var init_ok: bool = gs.mods.size() == 8 and is_equal_approx(gs.mods.damage, 1.0) \
		and is_equal_approx(gs.mods.move_speed, 1.0) and gs.mods.pierce == 0 \
		and gs.mods.projectiles == 0 and gs.upgrades_taken == 0 and gs.taken_upgrades.is_empty()
	_ck("INIT_MODS", init_ok, "cost=%d" % gs.crystals_for_next())

	# ---------- 3. 稀疏升级点：6 颗才触发一次 ----------
	var fired: Array = []
	gs.upgrade_ready.connect(func(c): fired.append(c))
	for i in 5:
		gs.add_crystal()
	var no_early: bool = gs.crystals == 5 and fired.is_empty() and gs.weapon_level == 1
	gs.add_crystal()
	var sparse_ok: bool = no_early and gs.crystals == 0 and gs.weapon_level == 2 \
		and fired.size() == 1 and fired[0].size() == 3 and gs.crystals_for_next() == 8
	_ck("SPARSE", sparse_ok, "cost_now=%d" % gs.crystals_for_next())

	# ---------- 4. 暂停 + 三张卡 ----------
	await process_frame
	var card_names: Array = []
	for i in 3:
		var card: Button = ui.get_node("Center/Cards/Card%d" % i)
		card_names.append(card.get_node("Name").text)
	var ui_ok: bool = ui != null and ui.visible and paused and tc != null and not tc.visible \
		and ui.get_node("Center/Cards/Card0").visible \
		and card_names[0] != "" and card_names[0] != card_names[1] \
		and card_names[1] != card_names[2] \
		and ui.get_node("Center/Eyebrow").text.contains("LEVEL 2")
	_ck("PAUSE_UI", ui_ok, "cards=%s" % str(card_names))

	# ---------- 5. 点击选卡：应用 → 恢复 ----------
	var applied: Array = []
	gs.upgrade_applied.connect(func(id): applied.append(id))
	var first_id: String = fired[0][0].id
	ui.get_node("Center/Cards/Card0").emit_signal("pressed")
	await process_frame
	var choose_ok: bool = applied.size() == 1 and applied[0] == first_id \
		and not ui.visible and not paused and tc.visible \
		and gs.taken_upgrades.get(first_id, 0) == 1 and gs.upgrades_taken == 1
	_ck("CHOOSE_CLICK", choose_ok, "id=%s" % first_id)

	# ---------- 6. 八张卡的乘区 / 加区（从干净基准开始，排除随机抽卡的干扰） ----------
	var m0: Dictionary = {"fire_rate": 1.0, "damage": 1.0, "projectiles": 0,
		"move_speed": 1.0, "max_health": 0.0, "magnet": 1.0, "pierce": 0, "bullet_speed": 1.0}
	gs.mods = m0.duplicate()
	gs.taken_upgrades.clear()
	gs.upgrades_taken = 0
	for id in ["fire_rate", "damage", "projectiles", "move_speed", "vitality", "magnet", "pierce", "bullet_speed"]:
		gs.apply_upgrade(id)
	var m1: Dictionary = gs.mods
	var mods_ok: bool = is_equal_approx(m1.fire_rate, 1.15) and is_equal_approx(m1.damage, 1.20) \
		and m1.projectiles == 1 and is_equal_approx(m1.move_speed, 1.12) \
		and is_equal_approx(m1.max_health, 25.0) and is_equal_approx(m1.magnet, 1.30) \
		and m1.pierce == 1 and is_equal_approx(m1.bullet_speed, 1.25) \
		and gs.upgrades_taken == 8 and gs.taken_upgrades.size() == 8
	_ck("MODS", mods_ok, "mods=%s" % str(m1))

	# ---------- 7. Player 重算（先归一到纯基础值再比较，避免旧乘区叠加） ----------
	gs.mods = {"fire_rate": 1.0, "damage": 1.0, "projectiles": 0, "move_speed": 1.0,
		"max_health": 0.0, "magnet": 1.0, "pierce": 0, "bullet_speed": 1.0}
	gs.upgrade_applied.emit("damage")
	var d0: float = player.bullet_damage
	var i0: float = player.fire_interval
	var p0: int = player.projectile_count
	gs.mods = {"fire_rate": 2.0, "damage": 2.0, "projectiles": 2, "move_speed": 1.5,
		"max_health": 50.0, "magnet": 1.0, "pierce": 0, "bullet_speed": 1.0}
	gs.upgrade_applied.emit("damage")
	var player_ok: bool = is_equal_approx(player.bullet_damage, d0 * 2.0) \
		and player.fire_interval < i0 and player.projectile_count == p0 + 2 \
		and is_equal_approx(player.max_health, 150.0) \
		and is_equal_approx(player.current_speed(), 330.0)
	_ck("PLAYER_RECALC", player_ok,
		"dmg=%.1f cd=%.3f proj=%d hp=%.0f spd=%.0f" % [
			player.bullet_damage, player.fire_interval, player.projectile_count,
			player.max_health, player.current_speed()])

	# ---------- 8. Bullet 弹速 / 射程 / 穿透 ----------
	var b: Area2D = load("res://scenes/world/Bullet.tscn").instantiate()
	root.add_child(b)
	b.set_physics_process(false)
	gs.mods.bullet_speed = 1.5
	gs.mods.pierce = 2
	b.setup(Vector2.RIGHT, 20.0)
	var bullet_ok: bool = is_equal_approx(b.speed, 930.0) and is_equal_approx(b.lifetime, 1.8) \
		and b.pierce_left == 2 and is_equal_approx(b.damage, 20.0)
	var e1 := FakeEnemy.new()
	var e2 := FakeEnemy.new()
	var e3 := FakeEnemy.new()
	for e in [e1, e2, e3]:
		root.add_child(e)
		e.add_to_group("enemy")
	b._on_body_entered(e1)
	var pierce_1: bool = b.active and b.pierce_left == 1 and is_equal_approx(e1.taken, 20.0)
	b._on_body_entered(e1)   # 同一只怪不许重复吃伤害
	var no_double: bool = is_equal_approx(e1.taken, 20.0) and b.pierce_left == 1
	b._on_body_entered(e2)
	var pierce_2: bool = b.active and b.pierce_left == 0
	b._on_body_entered(e3)
	var pierce_end: bool = not b.active
	_ck("BULLET_PIERCE", bullet_ok and pierce_1 and no_double and pierce_2 and pierce_end,
		"speed=%.0f life=%.2f left=%d" % [b.speed, b.lifetime, b.pierce_left])
	for e in [e1, e2, e3]:
		e.queue_free()
	b.queue_free()

	# ---------- 9. Pickup 磁吸半径 ----------
	var pk: Node2D = load("res://scenes/world/Pickup.tscn").instantiate()
	root.add_child(pk)
	gs.mods.magnet = 2.0
	var magnet_ok: bool = is_equal_approx(pk.magnet_radius(), 180.0)
	gs.mods.magnet = 1.0
	magnet_ok = magnet_ok and is_equal_approx(pk.magnet_radius(), 90.0)
	pk.queue_free()
	_ck("PICKUP_MAGNET", magnet_ok)

	# ---------- 10. HUD 接线 + 新卡 toast ----------
	var hud_ok: bool = hud.get_node_or_null("ToastLabel") != null \
		and hud.get_node_or_null("WeaponLabel") != null
	gs.upgrade_applied.emit("pierce")
	hud_ok = hud_ok and hud.get_node("ToastLabel").text.contains("贯穿孢针")
	_ck("HUD_TOAST", hud_ok, "toast=%s" % hud.get_node("ToastLabel").text)

	# ---------- 11. 键盘 1/2/3 ----------
	var applied_before: int = applied.size()
	gs.crystals = gs.crystals_for_next() - 1
	gs.add_crystal()
	await process_frame
	var kb_open: bool = ui.visible and paused
	var ev := InputEventKey.new()
	ev.keycode = KEY_2
	ev.pressed = true
	ui._input(ev)
	await process_frame
	var kb_ok: bool = kb_open and not ui.visible and not paused \
		and applied.size() == applied_before + 1
	_ck("KEYBOARD", kb_ok, "open=%s" % kb_open)

	# ---------- 12. 结算兜底（暂停中 end_run 不许把暂停带进结算） ----------
	gs.crystals = gs.crystals_for_next() - 1
	gs.add_crystal()
	await process_frame
	var before_end_paused: bool = paused
	gs.end_run()
	await process_frame
	var end_ok: bool = before_end_paused and not paused and not ui.visible
	_ck("GAMEOVER_SAFETY", end_ok)

	# ---------- 13. 重开重置 ----------
	gs.start_run()
	await process_frame
	var reset_ok: bool = gs.weapon_level == 1 and gs.crystals == 0 and gs.upgrades_taken == 0 \
		and gs.taken_upgrades.is_empty() and is_equal_approx(gs.mods.damage, 1.0) \
		and gs.mods.pierce == 0 and not paused
	_ck("RESET", reset_ok)

	# ---------- 清理隔离存档 ----------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(career.save_path))
	gs.save_path = "user://save.cfg"
	career.save_path = "user://career.cfg"
	# 让探针里 queue_free 的节点真正释放，避免退出时刷 ObjectDB leak 警告
	for i in 4:
		await process_frame

	print("PROBE_RESULT=", "PASS" if failed.is_empty() else "FAIL", " failed=", str(failed))
	quit(0 if failed.is_empty() else 1)
