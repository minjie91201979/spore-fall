extends Node
# 隔离实验：三种精灵同屏——ground.png / 运行时白块 / 无贴图 ColorRect
func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var arena: Node = get_tree().current_scene
	# 1. ground.png 精灵（导入管线纹理）
	var s1 := Sprite2D.new()
	s1.texture = load("res://assets/tiles/ground.png")
	s1.position = Vector2(-150, 0)
	s1.scale = Vector2(0.15, 0.15)
	s1.z_index = 0
	arena.add_child(s1)
	# 2. 运行时生成的纯绿纹理精灵（绕过导入管线）
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 1, 0))
	var s2 := Sprite2D.new()
	s2.texture = ImageTexture.create_from_image(img)
	s2.position = Vector2(150, 0)
	s2.z_index = 0
	arena.add_child(s2)
	await get_tree().create_timer(0.5).timeout
	var vp := get_viewport().get_visible_rect().size
	var shot: Image = get_viewport().get_texture().get_image()
	shot.save_png("C:/Users/musou/Desktop/object/spore-fall/build/tex_probe.png")
	var c1: Color = shot.get_pixel(int(vp.x/2) - 150, int(vp.y/2))
	var c2: Color = shot.get_pixel(int(vp.x/2) + 150, int(vp.y/2))
	print("PROBE ground_tex_pixel=%s green_tex_pixel=%s" % [c1, c2])
	get_tree().quit(0)
