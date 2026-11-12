extends SceneTree
# 图标生成工具：把 AI 产出的原图处理成三端所需的全套尺寸。
# 用法：Godot_console.exe --headless --path . --script tools/make_icons.gd
#
# AI 原图是「深色圆角方块 + 四角白底」的构图，处理步骤：
#   1) 按行/列统计暗色像素占比，找到圆角方块的外接矩形（不是按白边扫，
#      白色只在四角，按边框扫会裁进主体）
#   2) 裁出方块，缩放到 1024 母版
#   3) 四角做圆角抗锯齿透明（Windows ICO 与 Android 圆形遮罩都需要透明角）
#   4) 缩放出各端尺寸 + 用角落色生成 Android adaptive 背景层
#
# 产物（assets/icons/）：
#   icon_1024.png            项目主图标（project.godot config/icon）
#   icon_adaptive_432.png    Android adaptive 前景层
#   icon_adaptive_bg.png     Android adaptive 背景层
#   icon_192 / 256 / 128 / 64 / 48 / 32 / 16.png（192 给 legacy launcher，
#   256~16 由 tools/make_ico.py 合成 icon.ico 给 Windows EXE）

const SRC := "res://build/icon_raw.png"
const OUT_DIR := "res://assets/icons/"
const MASTER := 1024
const CORNER_RATIO := 0.185
const SIZES := [512, 432, 256, 192, 128, 64, 48, 32, 16]

func _initialize() -> void:
	var src_path: String = ProjectSettings.globalize_path(SRC)
	var img: Image = Image.load_from_file(src_path)
	if img == null:
		print("SRC_MISSING ", src_path)
		quit()
		return
	print("SRC_SIZE=", img.get_size())

	var rect := _dark_square_rect(img)
	print("SQUARE_RECT=", rect)
	var master: Image = img.get_region(rect)
	master.resize(MASTER, MASTER, Image.INTERPOLATE_LANCZOS)
	_round_corners(master, int(MASTER * CORNER_RATIO))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	master.save_png(ProjectSettings.globalize_path(OUT_DIR + "icon_1024.png"))
	print("SAVED icon_1024.png")
	for s in SIZES:
		var n: Image = master.duplicate()
		n.resize(s, s, Image.INTERPOLATE_LANCZOS)
		var name := "icon_%d.png" % s
		if s == 432:
			name = "icon_adaptive_432.png"
		n.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
		print("SAVED ", name)

	# Android adaptive 背景层：取方块内四边中点的暗色（避开被抠透明的四角）
	var bg: Image = Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	var acc := Color(0, 0, 0, 0)
	var edge := 48
	for p in [
		Vector2i(edge, MASTER / 2), Vector2i(MASTER - 1 - edge, MASTER / 2),
		Vector2i(MASTER / 2, edge), Vector2i(MASTER / 2, MASTER - 1 - edge),
	]:
		acc += master.get_pixelv(p)
	acc /= 4.0
	acc.a = 1.0
	bg.fill(acc)
	bg.save_png(ProjectSettings.globalize_path(OUT_DIR + "icon_adaptive_bg.png"))
	print("BG_COLOR=", acc)
	print("OK")
	quit()

# 圆角方块外接矩形：逐行/列统计「暗色」像素占比，占比过半的行/列即在方块内
func _dark_square_rect(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var top := _scan_rows(img, 0, 1, h, w)
	var bottom := _scan_rows(img, h - 1, -1, h, w)
	var left := _scan_cols(img, 0, 1, w, h)
	var right := _scan_cols(img, w - 1, -1, w, h)
	return Rect2i(left, top, right - left + 1, bottom - top + 1)

func _is_dark(c: Color) -> bool:
	return c.r + c.g + c.b < 1.2

func _scan_rows(img: Image, start: int, step: int, h: int, w: int) -> int:
	var y := start
	var limit := h / 2
	for i in limit:
		var dark := 0
		var samples := 0
		for x in range(0, w, 4):
			samples += 1
			if _is_dark(img.get_pixel(x, y)):
				dark += 1
		if dark > samples / 2:
			return y
		y += step
	return start

func _scan_cols(img: Image, start: int, step: int, w: int, h: int) -> int:
	var x := start
	var limit := w / 2
	for i in limit:
		var dark := 0
		var samples := 0
		for y in range(0, h, 4):
			samples += 1
			if _is_dark(img.get_pixel(x, y)):
				dark += 1
		if dark > samples / 2:
			return x
		x += step
	return start

# 四角圆角透明 + 一像素级抗锯齿（只处理四角 radius×radius 区域，不用全图遍历）
func _round_corners(img: Image, radius: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var corners := [
		[Vector2i(0, 0), Vector2i(1, 1)],
		[Vector2i(w - 1, 0), Vector2i(-1, 1)],
		[Vector2i(0, h - 1), Vector2i(1, -1)],
		[Vector2i(w - 1, h - 1), Vector2i(-1, -1)],
	]
	for corner in corners:
		var anchor: Vector2i = corner[0]
		var dir: Vector2i = corner[1]
		var cx := anchor.x + dir.x * radius
		var cy := anchor.y + dir.y * radius
		for dy in radius:
			for dx in radius:
				var px := anchor.x + dir.x * dx
				var py := anchor.y + dir.y * dy
				var d := Vector2(px - cx, py - cy).length()
				if d >= float(radius):
					var col := img.get_pixel(px, py)
					col.a = 0.0
					img.set_pixel(px, py, col)
				elif d > float(radius) - 1.5:
					var col := img.get_pixel(px, py)
					col.a *= clampf(radius - d, 0.0, 1.0)
					img.set_pixel(px, py, col)
