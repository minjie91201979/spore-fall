extends SceneTree
# 动画逐帧取证（带窗口，headless 取不到 framebuffer）。
# 把同一只怪在连续帧里的 Sprite 截取出来，另存为 build/anim_frames/NNNN.png，
# 再由 Python 拼成动作序列条。这里只负责「取帧」，拼接交给 PIL。
#
# 用法：Godot_console.exe --path . --script tools/shot_anim.gd
#   （不要加 --headless）

const OUT_DIR := "C:/Users/musou/Desktop/object/spore-fall/build/anim_frames"
const FRAMES := 12
const ENEMY_KEY := "corroder"   # 行走 + 远程喷吐，动作最丰富

func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# 纯色背景，便于观察轮廓；不加载整个 Arena，避免刷怪干扰
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.086, 0.11, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var st = load("res://assets/data/enemy_%s.tres" % ENEMY_KEY)
	var e := load("res://scenes/world/Enemy.tscn").instantiate() as Node2D
	root.add_child(e)
	current_scene = e
	e.global_position = Vector2(576, 324)
	e.set("active", true)
	e.call("configure", st)
	# 放大到能看清细节（仅取证用，不改游戏内体型）
	e.scale = Vector2.ONE * 5.0
	# 采样固定步长，关掉自动 _process，避免真实帧率叠加进来打乱相位
	e.set_process(false)
	# 给动画层一个「正在移动」的速度，才是完整步态幅度（静止只有 0.28 倍呼吸）
	e.set("velocity", Vector2(90, 0))

	var anim = e.get("anim")
	for i in FRAMES:
		# 手动推进动画层固定步长，保证每帧相位可复现（不依赖机器帧率）
		anim.call("tick", 0.055, e)
		await process_frame
		await process_frame
		var img: Image = root.get_texture().get_image()
		# 只裁怪物周围区域，减少后续拼接体积
		var crop := img.get_region(Rect2i(576 - 150, 324 - 150, 300, 300))
		crop.save_png("%s/f%02d.png" % [OUT_DIR, i])
	print("ANIM_FRAMES_SAVED ", FRAMES)

	# 单独取一组「事件姿态」：待机 / 蓄力 / 开火 / 受击 / 破土
	var poses := ["idle", "windup", "fire", "hit", "emerge"]
	for j in poses.size():
		anim.call("reset")
		match poses[j]:
			"windup": anim.call("pulse_charge")
			"fire": anim.call("pulse_fire", Vector2.RIGHT)
			"hit": anim.call("pulse_hit")
			"emerge": anim.call("pulse_emerge")
		anim.call("tick", 0.03, e)
		await process_frame
		await process_frame
		var img2: Image = root.get_texture().get_image()
		var crop2 := img2.get_region(Rect2i(576 - 150, 324 - 150, 300, 300))
		crop2.save_png("%s/pose_%s.png" % [OUT_DIR, poses[j]])
	print("ANIM_POSES_SAVED ", poses.size())
	quit(0)
