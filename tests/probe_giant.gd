extends Node
# 终极实验：删 Darkness，巨型色块压在玩家正上方
func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	var arena: Node = get_tree().current_scene
	var player: Node = get_tree().get_first_node_in_group("player")
	var dark: Node = arena.get_node_or_null("Darkness")
	if dark:
		dark.visible = false   # 关掉暗色滤镜
	print("PROBE player_pos=%s darkness_off=%s" % [player.global_position, dark != null])
	var pp: Vector2 = player.global_position
	# 红：Arena 子节点，就在玩家脚下，超大声
	var a := Polygon2D.new()
	a.polygon = PackedVector2Array([Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)])
	a.color = Color(1, 0, 0, 0.8)
	a.position = pp
	arena.add_child(a)
	# 蓝：根子节点
	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)])
	b.color = Color(0, 0.4, 1, 0.8)
	b.position = pp + Vector2(-300, 0)
	get_tree().root.add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE a.gpos=%s b.gpos=%s" % [a.global_position, b.global_position])
	await get_tree().create_timer(0.3).timeout
	_save_shot("giant_probe.png")
	print("PROBE DONE")
	get_tree().quit(0)

func _save_shot(file_name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img:
		img.save_png(dir.path_join(file_name))
