extends SceneTree
# 导航绕柱 + 固定方柱挡子弹。headless 冒烟。
# 固定方柱在 (380, -640)，碰撞 140×140，正对它走直线会被面挡住。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	var arena: Node2D = null
	for i in 40:
		await process_frame
		if current_scene and current_scene.name == "Arena":
			arena = current_scene
			break
	if arena == null:
		print("NO_ARENA")
		quit(1)
		return
	var spawner := arena.get_node_or_null("Spawner")
	if spawner:
		spawner.set_process(false)
	for i in 8:
		await physics_frame
	var region := arena.get_node("NavigationRegion2D") as NavigationRegion2D
	var map: RID = region.get_navigation_map()
	var pillar := arena.get_node("Pillar") as Node2D
	var poly: NavigationPolygon = region.navigation_polygon
	var poly_count := 0
	if poly:
		poly_count = poly.get_polygon_count()
	var poly_ok: bool = poly_count > 0
	print("NAV_POLYS ", poly_count)

	print("NAV_MAP valid=", map.is_valid(), " regions=", NavigationServer2D.map_get_regions(map).size(), " iter=", NavigationServer2D.map_get_iteration_id(map))
	print("NAV_POINT pillar_inside=", _covered(poly, pillar.global_position), " open_inside=", _covered(poly, Vector2(-200, 200)))
	var pillar_hole: float = NavigationServer2D.map_get_closest_point(map, pillar.global_position).distance_to(pillar.global_position)
	var random_hole := 0.0
	var random_body: Node2D = null
	for node in get_nodes_in_group("obstacle"):
		if node == pillar or not node is Node2D:
			continue
		random_body = node
		random_hole = NavigationServer2D.map_get_closest_point(map, random_body.global_position).distance_to(random_body.global_position)
		break
	var open_pt := Vector2(-200, 200)
	var open_gap: float = NavigationServer2D.map_get_closest_point(map, open_pt).distance_to(open_pt)
	print("NAV_HOLES pillar=%.1f random=%.1f open=%.1f" % [pillar_hole, random_hole, open_gap])

	# 洞已经烘焙完。把随机柱的物理体挪走，只留固定方柱挡在直线上，
	# 这样「贴着柱面停住」不会被圆柱滑动误判成绕路。
	var parked := 0
	for node in get_nodes_in_group("obstacle"):
		if node == pillar or not node is Node2D:
			continue
		(node as Node2D).global_position = Vector2(1400, 1400 + parked * 90.0)
		parked += 1
	var player := get_first_node_in_group("player") as Node2D
	player.set("health", 100000.0)
	var approach := Vector2.DOWN
	player.global_position = pillar.global_position + approach * 180.0
	var pool := get_first_node_in_group("enemy_pool")
	var enemy: Node2D = pool.acquire(arena)
	enemy.configure(load("res://assets/data/enemy_walker.tres"))
	var start: Vector2 = pillar.global_position - approach * 220.0
	enemy.global_position = start
	var lateral := 0.0
	for i in 180:
		await physics_frame
		var travelled: Vector2 = enemy.global_position - start
		lateral = maxf(lateral, absf(travelled.cross(approach)))
	var around: bool = lateral > 36.0
	print("NAV_AROUND lateral=%.1f pos=%s" % [lateral, enemy.global_position])

	var bullet: Area2D = load("res://scenes/world/Bullet.tscn").instantiate()
	bullet.global_position = pillar.global_position + Vector2(-220, 0)
	arena.add_child(bullet)
	bullet.setup(Vector2.RIGHT, 10.0)
	var blocked := false
	var bullet_x := bullet.global_position.x
	for i in 40:
		await physics_frame
		if not is_instance_valid(bullet) or not bullet.active:
			blocked = true
			break
		bullet_x = bullet.global_position.x
	print("PILLAR_BLOCKS_BULLET blocked=%s x=%.1f" % [blocked, bullet_x])

	var pillar_carved: bool = pillar_hole > 40.0 and pillar_hole < 160.0
	var random_carved: bool = random_body != null and random_hole > 15.0 and random_hole < 120.0
	var all_ok: bool = poly_ok and pillar_carved and random_carved \
		and open_gap < 2.0 and around and blocked and pillar.is_in_group("obstacle")
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)

func _covered(nav: NavigationPolygon, point: Vector2) -> bool:
	if nav == null:
		return false
	var verts := nav.get_vertices()
	for i in nav.get_polygon_count():
		var poly: PackedInt32Array = nav.get_polygon(i)
		var pts := PackedVector2Array()
		pts.resize(poly.size())
		for j in poly.size():
			pts[j] = verts[poly[j]]
		if Geometry2D.is_point_in_polygon(point, pts):
			return true
	return false
