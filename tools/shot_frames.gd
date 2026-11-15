extends SceneTree
# 帧序列实机取证（带窗口，headless 取不到 framebuffer）。
# 直接驱动 FramePlayer 按固定步长推进，把每一帧的贴图裁出来，
# 用于证明「游戏内真的在按帧001→帧002…播放」，而非仅资源存在。

const OUT_DIR := "C:/Users/musou/Desktop/object/spore-fall/build/frame_shots"
const KEY := "corroder"

func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.086, 0.11, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var st = load("res://assets/data/enemy_%s.tres" % KEY)
	var e := load("res://scenes/world/Enemy.tscn").instantiate() as Node2D
	root.add_child(e)
	current_scene = e
	e.global_position = Vector2(576, 324)
	e.set("active", true)
	e.call("configure", st)
	e.scale = Vector2.ONE * 4.2
	e.set_process(false)   # 关自动 tick，手动精确推进相位

	var fp = e.get("frames")
	fp.call("tick", 0.001)   # 首次 tick 完成加载

	# 循环剪辑：帧001..帧004 逐帧采样
	var i := 0
	while i < 4:
		await process_frame
		await process_frame
		var img: Image = root.get_texture().get_image()
		img.get_region(Rect2i(576 - 140, 324 - 140, 280, 280)).save_png(
			"%s/loop_%03d.png" % [OUT_DIR, i + 1])
		fp.call("tick", 0.084)   # > 1/12 秒，前进一帧
		i += 1

	# 单次剪辑：触发后同样逐帧采样
	fp.call("play_once")
	i = 0
	while i < 4:
		await process_frame
		await process_frame
		var img2: Image = root.get_texture().get_image()
		img2.get_region(Rect2i(576 - 140, 324 - 140, 280, 280)).save_png(
			"%s/act_%03d.png" % [OUT_DIR, i + 1])
		fp.call("tick", 0.084)
		i += 1
	print("FRAME_SHOTS_SAVED 8")
	quit(0)
