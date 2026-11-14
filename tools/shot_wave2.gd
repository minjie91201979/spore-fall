extends SceneTree
# 第二波「深巢反扑」画面证据（带窗口运行，headless 取不到 framebuffer）。
# 产出两张：
#   wave2_card.png  —— 第一波 BOSS 击溃后弹出的「第二波 / WAVE 2」过渡提示卡
#   wave2_scene.png —— 第二波三只新怪 + 渊噬孢 BOSS 在竞技场里的实机渲染
# 说明：仅为截图展示，会把新怪/BOSS 摆到镜头附近便于观察贴图，不改动游戏逻辑。
# 用法：Godot_console.exe --path . --script tools/shot_wave2.gd   （不要加 --headless）

const OUT_CARD := "C:/Users/musou/Desktop/object/spore-fall/build/wave2_card.png"
const OUT_SCENE := "C:/Users/musou/Desktop/object/spore-fall/build/wave2_scene.png"

func _init() -> void:
	await process_frame
	var arena = load("res://scenes/world/Arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.4).timeout   # 等 WaveMode 发起第一波 BOSS

	# ---- 击溃第一波 BOSS → 弹出过渡卡 ----
	var boss1 := _find_boss("母巢孢")
	if boss1:
		boss1.take_damage(boss1.max_health + 1.0)
	await create_timer(0.8, true).timeout   # 暂停时计时器仍需推进
	_save(OUT_CARD)

	# ---- 继续 → 第二波 ----
	var card = current_scene.get_node_or_null("UILayer/WaveCard")
	if card and card.has_method("_on_continue"):
		card._on_continue()
	var wm = current_scene.get_node_or_null("WaveMode")
	if wm:
		wm.set("wave2_delay", 0.0)   # 立刻召唤渊噬孢，免去等待墙钟
	await create_timer(0.9, true).timeout

	# ---- 把新怪/BOSS 摆到镜头附近，做一张清晰的贴图展示图 ----
	var player = get_first_node_in_group("player")
	var origin: Vector2 = player.global_position if player else Vector2.ZERO
	var slots := [Vector2(-190, -70), Vector2(150, -110), Vector2(-120, 150), Vector2(190, 140)]
	var idx := 0
	for e in get_nodes_in_group("enemy"):
		if not e.get("active") or e.get("is_boss"):
			continue
		var st = e.get("stats")
		if st == null:
			continue
		if ("Corroder" in st.display_name or "Burrower" in st.display_name
				or "Bloom" in st.display_name) and idx < slots.size():
			e.global_position = origin + slots[idx]
			idx += 1
	var boss2 := _find_boss("渊噬孢")
	if boss2:
		boss2.global_position = origin + Vector2(0, -250)
	await create_timer(0.5, true).timeout
	_save(OUT_SCENE)
	quit(0)

func _find_boss(substr: String) -> Node:
	for e in get_nodes_in_group("boss"):
		if e.get("active"):
			var st = e.get("stats")
			if st and substr in st.display_name:
				return e
	return null

func _save(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("SHOT_SAVED ", path, " ", img.get_width(), "x", img.get_height())
