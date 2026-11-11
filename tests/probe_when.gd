extends Node
# 追踪玩家 global_position 变化时间线
var _pp: Vector2 = Vector2.ZERO
var _last: Vector2 = Vector2.ZERO
func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		print("PROBE no player"); get_tree().quit(1); return
	set_process(true)
	_last = player.global_position
	print("PROBE t=0.1 player=%s" % _last)
	for i in range(10):
		await get_tree().create_timer(0.1).timeout
		var p: Vector2 = player.global_position
		if p.distance_to(_last) > 5.0:
			print("PROBE t=%.1f MOVED %s -> %s" % [0.2 + i * 0.1, _last, p])
			_last = p
	print("PROBE final=%s" % player.global_position)
	get_tree().quit(0)
