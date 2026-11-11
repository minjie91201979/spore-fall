extends SceneTree
# 校验 Arena._ready 是否完整跑完（GroundRoot 是否生成）
func _init() -> void:
	var arena: Node = load("res://scenes/world/Arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var g: Node = arena.get_node_or_null("GroundRoot")
	if g == null:
		print("GROUND-CHECK FAIL: GroundRoot missing")
		quit(1)
		return
	var sprites: int = g.get_child_count()
	print("GROUND-CHECK OK: GroundRoot children=%d" % sprites)
	quit(0 if sprites > 0 else 1)
