extends Node
# 列出 player 组里所有节点及其身份
func _ready() -> void:
	await get_tree().create_timer(0.3).timeout
	var nodes := get_tree().get_nodes_in_group("player")
	print("PROBE player_group_count=%d" % nodes.size())
	for n in nodes:
		print("PROBE member: %s | scene=%s | parent=%s | gpos=%s | class=%s" % [
			n.name, n.get("scene_file_path"), n.get_parent().name, n.global_position, n.get_class()])
	get_tree().quit(0)
