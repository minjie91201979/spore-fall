extends SceneTree
# 铺垫期实机取证：确认 45s 铺垫期的倒计时目标栏在生存模式 HUD 上可见且不遮挡。
# 带窗口运行（headless 取不到 framebuffer）。

const OUT := "C:/Users/musou/Desktop/object/spore-fall/build/warmup_hud.png"

func _init() -> void:
	await process_frame
	var arena = load("res://scenes/world/Arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.5).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT)
	print("SHOT_SAVED ", OUT, " ", img.get_width(), "x", img.get_height())
	quit(0)
