extends Node2D
# 主战场入口：场景就绪即启动无尽循环（§11.4.4）。
# 地面用网格化 Sprite 平铺，规避 TileMap/TileSet 在弱 GPU 上的兼容风险。

@export var ground_texture: Texture2D
@export var ground_tile: float = 512.0
@export var ground_grid: int = 5
@export var obstacle_count: int = 8

const OBSTACLE_SCENE := preload("res://scenes/world/Obstacle.tscn")
# 导航外框与玩家活动范围一致。随机柱在这一帧之后才存在，场景里那份多边形只挖了固定方柱。
const NAV_HALF := 900.0
# 杂兵碰撞半径约 14。烘焙时把可行走区域内缩，路径中心就不会贴着柱壁蹭。
const NAV_AGENT_RADIUS := 18.0

func _ready() -> void:
	GameState.start_run()
	# 生存局显式无限弹药，避免刚打完剧情把消耗制带进 Arena
	var player := get_node_or_null("Player")
	if player:
		player.infinite_ammo = true
	Sfx.start_bgm()
	Sfx.start_ambient("amb_forest")
	_build_ground()
	_spawn_obstacles()
	# 场景分组有时要等进树才挂上；烘焙前再确认一次，避免这根方柱被漏挖。
	var pillar := get_node_or_null("Pillar")
	if pillar and not pillar.is_in_group("obstacle"):
		pillar.add_to_group("obstacle")
	_rebake_navigation()

# 随机撒障碍柱：避开玩家出生圈（260px），柱间最小间距 260px，
# 保证任一柱子都可以从两侧绕过。先摆位再入树（池化教训同款）。
func _spawn_obstacles() -> void:
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < obstacle_count and attempts < 300:
		attempts += 1
		var p := Vector2(randf_range(-900.0, 900.0), randf_range(-900.0, 900.0))
		if p.length() < 260.0:
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 260.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
	for p in placed:
		var o: Node2D = OBSTACLE_SCENE.instantiate()
		o.position = p
		o.rotation = randf() * TAU
		o.scale = Vector2.ONE * randf_range(0.85, 1.3)
		add_child(o)

# 固定方柱 + 刚撒下的随机柱一起挖洞，再交给 NavigationRegion2D。
# 同步烘焙：这一帧结束前多边形就有洞，随后刷出来的杂兵才能绕开，而不是只绕场景里那根方柱。
func _rebake_navigation() -> void:
	var region := get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if region == null:
		push_error("Arena 缺少 NavigationRegion2D，敌人无法绕柱")
		return
	var nav := NavigationPolygon.new()
	nav.agent_radius = NAV_AGENT_RADIUS
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_rect_outline(Vector2.ZERO, Vector2(NAV_HALF * 2.0, NAV_HALF * 2.0)))
	var carved := 0
	for node in get_tree().get_nodes_in_group("obstacle"):
		if not node is Node2D:
			continue
		var outline := _obstruction_outline(region, node as Node2D)
		if outline.size() < 3:
			continue
		source.add_obstruction_outline(outline)
		carved += 1
	NavigationServer2D.bake_from_source_geometry_data(nav, source)
	if nav.get_polygon_count() <= 0:
		push_error("导航烘焙结果为空（障碍 %d），保留场景里的旧多边形" % carved)
		return
	region.navigation_polygon = nav

func _obstruction_outline(region: NavigationRegion2D, body: Node2D) -> PackedVector2Array:
	var col := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or col.shape == null:
		return PackedVector2Array()
	var center: Vector2 = region.to_local(col.global_position)
	var scl: Vector2 = col.global_scale
	var shape := col.shape
	if shape is CircleShape2D:
		var radius: float = shape.radius * maxf(absf(scl.x), absf(scl.y))
		return _circle_outline(center, radius, 12)
	if shape is RectangleShape2D:
		var size := Vector2(shape.size.x * absf(scl.x), shape.size.y * absf(scl.y))
		return _rect_outline(center, size)
	return PackedVector2Array()

func _rect_outline(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

func _circle_outline(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments)
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts[i] = center + Vector2(cos(a), sin(a)) * radius
	return pts

func _build_ground() -> void:
	if not ground_texture:
		return
	var root := Node2D.new()
	root.name = "GroundRoot"
	add_child(root)
	var half: int = ground_grid / 2
	for gx in range(-half, half + 1):
		for gy in range(-half, half + 1):
			var s := Sprite2D.new()
			s.texture = ground_texture
			s.centered = true
			s.position = Vector2(gx, gy) * ground_tile
			s.z_index = -10
			root.add_child(s)
