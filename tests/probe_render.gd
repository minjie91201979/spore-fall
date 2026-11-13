extends Node
# 临时探针：带窗口跑 1 秒后截屏保存，检查地面是否真的渲染
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var img: Image = get_viewport().get_texture().get_image()
	var shot_dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	img.save_png(shot_dir.path_join("render_probe.png"))
	# 取画面中心与四角像素颜色，判断是否是纯默认背景色
	var vp := get_viewport().get_visible_rect().size
	var center: Color = img.get_pixel(int(vp.x/2), int(vp.y/2))
	var corner: Color = img.get_pixel(10, 10)
	print("PROBE center=%s corner=%s" % [center, corner])
	var g: Node = get_tree().current_scene.get_node_or_null("GroundRoot")
	print("PROBE ground_nodes=%s" % (g.get_child_count() if g else -1))
	get_tree().quit(0)
