extends RefCounted
class_name StoryWorld
# 剧情关的墙、地面和导航。复用 Arena 的地面贴图与烘焙方式，不另做光照系统。

const GROUND := "res://assets/tiles/ground.png"

static func add_ground(parent: Node2D, origin: Vector2, half: int, tint: Color) -> void:
	var tex: Texture2D = load(GROUND)
	var root := Node2D.new()
	root.name = "GroundRoot"
	root.z_index = -10
	parent.add_child(root)
	for gx in range(-half, half + 1):
		for gy in range(-half, half + 1):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = true
			s.position = origin + Vector2(gx, gy) * 512.0
			s.modulate = tint
			s.z_index = -10
			root.add_child(s)

static func add_wall(parent: Node2D, center: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("obstacle")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var vis := Polygon2D.new()
	var h := size * 0.5
	vis.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
		Vector2(h.x, h.y), Vector2(-h.x, h.y),
	])
	vis.color = color
	body.add_child(vis)
	# 亮色描边：墙体与暗色地面同亮度时分不清边界，统一加高对比轮廓线
	var edge := Line2D.new()
	var pts := PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
		Vector2(h.x, h.y), Vector2(-h.x, h.y),
		Vector2(-h.x, -h.y),
	])
	edge.points = pts
	edge.width = 4.0
	edge.default_color = Color(0.74, 0.84, 0.88, 0.9)   # 冷调亮青白，暗景下依然醒目
	edge.z_index = 1
	body.add_child(edge)
	parent.add_child(body)
	return body

static func add_patch(parent: Node2D, center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var vis := Polygon2D.new()
	vis.position = center
	var h := size * 0.5
	vis.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
		Vector2(h.x, h.y), Vector2(-h.x, h.y),
	])
	vis.color = color
	vis.z_index = -5
	parent.add_child(vis)
	return vis

static func add_light(parent: Node2D, pos: Vector2, color: Color, energy: float) -> PointLight2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 1.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var light := PointLight2D.new()
	light.texture = tex
	light.position = pos
	light.color = color
	light.energy = energy
	light.texture_scale = 4.0
	parent.add_child(light)
	return light

static func bake(region: NavigationRegion2D, blocks: Array) -> void:
	var nav := NavigationPolygon.new()
	nav.agent_radius = 18.0
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(PackedVector2Array([
		Vector2(-940, -940), Vector2(940, -940), Vector2(940, 940), Vector2(-940, 940),
	]))
	for block in blocks:
		var c: Vector2 = block.center
		var s: Vector2 = block.size
		var h := s * 0.5
		source.add_obstruction_outline(PackedVector2Array([
			c + Vector2(-h.x, -h.y),
			c + Vector2(h.x, -h.y),
			c + Vector2(h.x, h.y),
			c + Vector2(-h.x, h.y),
		]))
	NavigationServer2D.bake_from_source_geometry_data(nav, source)
	if nav.get_polygon_count() > 0:
		region.navigation_polygon = nav
	else:
		push_error("剧情导航烘焙为空")

static func interactable(parent: Node, pos: Vector2, prompt: String) -> Interactable:
	var node := Interactable.new()
	node.position = pos
	node.prompt = prompt
	parent.add_child(node)
	return node
