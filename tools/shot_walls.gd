extends SceneTree

const OUT := "C:/Users/musou/Desktop/object/spore-fall/build/walls_check.png"

func _init() -> void:
	await process_frame
	var packed = load("res://scenes/story/Safehouse.tscn")
	var inst = packed.instantiate()
	root.add_child(inst)
	current_scene = inst
	await create_timer(1.2).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT)
	print("SHOT_SAVED ", OUT, " ", img.get_width(), "x", img.get_height())
	quit(0)
