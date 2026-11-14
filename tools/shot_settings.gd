extends SceneTree

const OUT := "C:/Users/musou/Desktop/object/spore-fall/build/settings_check.png"

func _init() -> void:
	await process_frame
	var inst = load("res://scenes/ui/Title.tscn").instantiate()
	root.add_child(inst)
	current_scene = inst
	await create_timer(0.9).timeout
	var sp = load("res://scripts/ui/SettingsPanel.gd").new()
	root.add_child(sp)
	sp.open()
	await create_timer(0.4).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT)
	print("SHOT_SAVED ", OUT)
	quit(0)
