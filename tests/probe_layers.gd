extends Node
# 最终隔离：三个纯色标记块，分别挂在 Arena / 根 / Player 下
func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	var arena: Node = get_tree().current_scene
	var player: Node = get_tree().get_first_node_in_group("player")
	print("PROBE arena=%s player=%s" % [arena.name if arena else "null", player.name if player else "null"])
	# A: Arena 直接子节点，红色块
	var a := Polygon2D.new()
	a.polygon = PackedVector2Array([Vector2(-40,-40), Vector2(40,-40), Vector2(40,40), Vector2(-40,40)])
	a.color = Color(1, 0, 0)
	a.position = Vector2(0, -200)
	arena.add_child(a)
	# B: 根 viewport 子节点，蓝色块
	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(-40,-40), Vector2(40,-40), Vector2(40,40), Vector2(-40,40)])
	b.color = Color(0, 0.4, 1)
	b.position = Vector2(-200, 0)
	get_tree().root.add_child(b)
	# C: Player 子节点，黄色块（Player 肯定能渲染）
	if player:
		var c := Polygon2D.new()
		c.polygon = PackedVector2Array([Vector2(-40,-40), Vector2(40,-40), Vector2(40,40), Vector2(-40,40)])
		c.color = Color(1, 1, 0)
		c.position = Vector2(200, 0)
		player.add_child(c)
	# D: Sprite2D 挂 Arena，白色块（对照：Polygon2D vs Sprite2D）
	var d := Sprite2D.new()
	var img := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1))
	d.texture = ImageTexture.create_from_image(img)
	d.position = Vector2(0, 200)
	arena.add_child(d)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("C:/Users/musou/Desktop/object/spore-fall/build/layer_probe.png")
	print("PROBE DONE")
	get_tree().quit(0)
