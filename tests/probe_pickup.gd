extends Node
# 临时探针：直接在玩家旁生成医疗包+晶体各一，截图确认渲染与磁吸
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var arena: Node = get_tree().current_scene
	var player: Node = get_tree().get_first_node_in_group("player")
	print("PROBE player_pos=%s" % player.global_position)
	var scene: PackedScene = load("res://scenes/world/Pickup.tscn")
	# 沿玩家右侧排一列三种状态：医疗包 / 晶体 / 磁吸距离内的晶体
	for cfg in [["heal", Vector2(60, 0)], ["crystal", Vector2(110, 0)], ["crystal", Vector2(80, 0)]]:
		var pk: Node2D = scene.instantiate()
		pk.kind = cfg[0]
		pk.position = player.global_position + cfg[1]
		arena.add_child(pk)
	var t0: float = player.global_position.x
	await get_tree().create_timer(0.8).timeout
	_save_shot("pickup_probe.png")
	var left: Array = get_tree().get_nodes_in_group("pickup")
	print("PROBE pickups_left=%d" % left.size())
	# 磁吸距离内（80px）的晶体应被吸近玩家
	var moved := false
	for pk in left:
		if pk.global_position.distance_to(player.global_position) < 60.0:
			moved = true
	print("PROBE magnet_pull=%s player_x=%.0f" % [moved, player.global_position.x])
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
