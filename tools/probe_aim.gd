extends SceneTree

func _init() -> void:
	await process_frame
	var settings = root.get_node("Settings")
	var p = load("res://scenes/world/Player.tscn").instantiate()
	root.add_child(p)
	current_scene = p
	await process_frame
	p.set("control_mode", 0)
	p.set("is_dead", false)

	# 运行时造一个最小「活敌」，只提供 _auto_aim_dir 需要的 active 字段
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar active: bool = true\n"
	var err := scr.reload()
	assert(err == OK, "runtime enemy script compile failed")
	var e := Node2D.new()
	e.set_script(scr)
	e.global_position = p.global_position + Vector2(0, 200)   # 正下方
	root.add_child(e)
	e.add_to_group("enemy")

	var d_on := _fire_dir(p, settings, true)
	var d_off := _fire_dir(p, settings, false)
	print("AIM_ON=", d_on, " AIM_OFF=", d_off)
	assert(d_on.dot(Vector2.DOWN) > 0.8, "自瞄开启时未朝敌人")
	assert(d_off.dot(Vector2.RIGHT) > 0.8, "自瞄关闭时未朝最后移动方向")
	print("AIM_PROBE_OK")
	quit(0)

func _fire_dir(p, settings, on: bool) -> Vector2:
	settings.auto_aim = on
	p.set("ammo", 50)
	p.set("_fire_cd", 0.0)
	p.set("_last_dir", Vector2.RIGHT)
	var before := {}
	for c in p.get_children():
		before[c.get_instance_id()] = true
	p.fire()
	for c in p.get_children():
		if before.has(c.get_instance_id()):
			continue
		if c is Area2D:
			return (c.global_position - p.global_position).normalized()
	return Vector2.ZERO
