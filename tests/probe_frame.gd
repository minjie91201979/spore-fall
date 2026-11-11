extends Node
# 逐帧追踪玩家位置 + 停车场敌人状态
var _frame := 0
var _armed := false
func _ready() -> void:
	await get_tree().create_timer(0.05).timeout
	_armed = true
func _physics_process(_d: float) -> void:
	if not _armed or _frame > 60:
		return
	_frame += 1
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var p: Vector2 = player.global_position
	if p.length() > 50000.0:
		print("PROBE frame=%d PLAYER JUMPED TO %s" % [_frame, p])
		_dump()
		_armed = false
	elif _frame % 10 == 0:
		print("PROBE frame=%d player=%s" % [_frame, p])
	if _frame == 60:
		_dump()
		get_tree().quit(0)

func _dump() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var parked := 0
	var actives := 0
	for e in enemies:
		if e.global_position.length() > 50000.0:
			parked += 1
			if e.get("active"):
				actives += 1
	print("PROBE enemies=%d parked=%d parked_active=%d" % [enemies.size(), parked, actives])
	var pools := get_tree().get_nodes_in_group("enemy_pool")
	for pl in pools:
		var kids: int = pl.get_child_count()
		var park: int = 0
		for c in pl.get_children():
			if c is Node2D and c.global_position.length() > 50000.0:
				park += 1
		print("PROBE pool=%s children=%d parked_kids=%d free=%d" % [pl.name, kids, park, pl._free_nodes.size()])
