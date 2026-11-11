extends Node
# 临时探针：启动后等场景就绪，检查 Arena 的 GroundRoot 是否生成
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var arena: Node = get_tree().current_scene
	if arena == null:
		print("PROBE FAIL: no current_scene")
		get_tree().quit(1)
		return
	var g: Node = arena.get_node_or_null("GroundRoot")
	var n: int = g.get_child_count() if g else 0
	if g and n > 0:
		print("PROBE PASS: GroundRoot sprites=%d" % n)
		get_tree().quit(0)
	else:
		print("PROBE FAIL: GroundRoot missing (arena children: %s)" % [arena.get_children().map(func(c): return c.name)])
		get_tree().quit(1)
