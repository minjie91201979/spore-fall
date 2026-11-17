extends SceneTree
# 专项：链结孢视觉连线（Line2D）生命周期。
# 断言：无对家隐藏 → 配对后出线 → 两点坐标正确 → 解链后隐藏 → 池化复用不残留。

var gs: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	await _frames(15)
	gs = get_root().get_node_or_null("GameState")
	if gs and not gs.is_running:
		gs.start_run()

	var wm: Node = current_scene.get_node_or_null("WaveMode")
	if wm:
		wm.set("wave1_delay", 0.0)
	await _frames(25)

	# 直接造两只 linker，避免依赖随机刷怪
	var a := _spawn_linker(Vector2(0, 0))
	var b := _spawn_linker(Vector2(120, 0))
	_check(a != null and b != null, "LINKERS_SPAWNED")
	if a == null or b == null:
		_fail_exit(); return

	var la: Line2D = a.get_node_or_null("LinkLine") as Line2D
	var lb: Line2D = b.get_node_or_null("LinkLine") as Line2D
	_check(la != null and lb != null, "LINKLINE_NODES_EXIST")
	if la == null or lb == null:
		_fail_exit(); return

	# 1) 初始：无对家 → 隐藏
	_check(not la.visible, "LINKLINE_HIDDEN_INITIALLY")
	_check(not lb.visible, "LINKLINE_B_HIDDEN_INITIALLY")

	# 2) 建立配对 → 只有 id 较小一方出线
	a._register_link(b.get_instance_id(), b.stats)
	b._register_link(a.get_instance_id(), a.stats)
	await _frames(3)
	var small: Node = a if a.get_instance_id() < b.get_instance_id() else b
	var big: Node = b if small == a else a
	var ls: Line2D = small.get_node_or_null("LinkLine") as Line2D
	var lg: Line2D = big.get_node_or_null("LinkLine") as Line2D
	_check(ls.visible, "LINKLINE_SHOWN_ON_SMALL_ID")
	_check(not lg.visible, "LINKLINE_HIDDEN_ON_LARGE_ID")

	# 3) 两点坐标：起点原点，终点指向对家
	if ls.visible:
		var pts: PackedVector2Array = ls.points
		_check(pts.size() == 2, "LINKLINE_TWO_POINTS(size=%d)" % pts.size())
		_check(pts[0].length() < 0.01, "LINKLINE_STARTS_AT_ORIGIN")
		var expected: Vector2 = small.to_local(big.global_position) if small == a else small.to_local(a.global_position)
		_check(pts[1].distance_to(expected) < 2.0,
			"LINKLINE_ENDS_AT_PARTNER(exp=%s got=%s)" % [str(expected), str(pts[1])])

	# 4) 移动对家 → 线跟着更新
	big.global_position += Vector2(90, 45)
	await _frames(3)
	if ls.visible:
		var moved_expected: Vector2 = small.to_local(big.global_position)
		_check(ls.points[1].distance_to(moved_expected) < 2.0, "LINKLINE_FOLLOWS_MOVEMENT")

	# 5) 解链 → 双方线都隐藏
	small._dissolve_link()
	await _frames(3)
	_check(not ls.visible, "LINKLINE_HIDDEN_AFTER_DISSOLVE")
	_check(not lg.visible, "LINKLINE_B_HIDDEN_AFTER_DISSOLVE")
	_check(small._link_partner_id == -1 and big._link_partner_id == -1, "BOTH_UNLINKED")

	# 6) 死亡 → 线隐藏（重新配对后杀掉对家）
	a._register_link(b.get_instance_id(), b.stats)
	b._register_link(a.get_instance_id(), a.stats)
	await _frames(3)
	# 伤害要远超血量：链结分摊会把一半转给对家，单次 max+1 打不死
	b.take_damage(b.max_health * 10.0)
	await _frames(8)
	_check(not la.visible and not lb.visible, "LINKLINE_HIDDEN_AFTER_PARTNER_DEATH")

	print("LINKLINE_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

func _spawn_linker(pos: Vector2) -> Node:
	var pool: Node = get_first_node_in_group("enemy_pool")
	if pool == null:
		return null
	var e: Node = pool.acquire(current_scene)
	if e == null:
		return null
	e.configure(load("res://assets/data/enemy_linker.tres"))
	e.global_position = pos
	return e

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1; print("PASS ", label)
	else:
		failc += 1; print("FAIL ", label)

var passc: int = 0
var failc: int = 0

func _fail_exit() -> void:
	print("LINKLINE_PASS=%d FAIL=%d" % [passc, failc])
	print("FAILED")
	quit()
