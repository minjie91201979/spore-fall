extends Node
# 特写截图：把玩家移到柱子西侧 150px，手电照亮柱子，验证视觉
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var player: Node = get_tree().get_first_node_in_group("player")
	var obstacles := get_tree().get_nodes_in_group("obstacle")
	var pillar: Node2D = obstacles[0]
	player.global_position = pillar.global_position + Vector2(-150, 0)
	player._last_dir = Vector2.RIGHT
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("C:/Users/musou/Desktop/object/spore-fall/build/pillar_probe.png")
	print("PROBE pillar at %s, shot saved" % pillar.global_position)
	get_tree().quit(0)
