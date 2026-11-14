extends SceneTree
# 精灵贴图后处理：把 agnes-image 产出的「白底彩图」变成可用的游戏精灵。
# 用法：Godot_console.exe --headless --path . --script tools/make_sprites.gd
#
# 关键设计：
#   1) 背景剔除用「从四边泛洪」而不是全局去白——主体内部的白色高光不会被误删；
#   2) 主体按长边归一化到 SUBJECT 像素，保证各变种在屏幕上的体型比例稳定
#      （贴图分辨率不同也没关系，运行期只用 scale 控制）；
#   3) 贴到透明方画布中心，Sprite2D 居中锚点直接可用。

const SRC_DIR := "res://build/sprites_raw/"
const OUT_DIR := "res://assets/characters/"
const OUT_SIZE := 256
const SUBJECT := 210     # 主体长边在 256 画布中的占比（约 82%，与旧素材观感一致）
const WHITE_TOL := 0.24  # 「接近白」判定：(1-r)+(1-g)+(1-b) 的和小于该值

const JOBS := {
	"walker.png": "enemy_walker.png",
	"runner.png": "enemy_runner.png",
	"brute.png": "enemy_brute.png",
	"lurker.png": "enemy_lurker.png",
	"boss.png": "enemy_boss.png",
	"player.png": "player.png",
	"miasma.png": "enemy_miasma.png",
	"splitter.png": "enemy_splitter.png",
	"spitter.png": "enemy_spitter.png",
	"sprayer.png": "enemy_sprayer.png",
	"corroder.png": "enemy_corroder.png",
	"burrower.png": "enemy_burrower.png",
	"bloom.png": "enemy_bloom.png",
	"abyss.png": "enemy_abyss.png",
}

func _initialize() -> void:
	for src in JOBS:
		var src_path: String = SRC_DIR + (src as String)
		if not FileAccess.file_exists(src_path):
			print("MISSING ", src)
			continue
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(src_path))
		if img == null:
			print("MISSING ", src)
			continue
		# 源图可能是 RGB8（无 alpha），blend_rect 要求与画布同为 RGBA8，否则静默跳过产出全透明图
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_remove_white_bg(img)
		var rect := _content_rect(img)
		if rect.size.x <= 0 or rect.size.y <= 0:
			print("EMPTY ", src)
			continue
		var cropped: Image = img.get_region(rect)
		var cw := cropped.get_width()
		var ch := cropped.get_height()
		var nw: int = SUBJECT
		var nh: int = SUBJECT
		if cw >= ch:
			nh = int(round(float(ch) * float(SUBJECT) / float(cw)))
		else:
			nw = int(round(float(cw) * float(SUBJECT) / float(ch)))
		cropped.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		var canvas: Image = Image.create_empty(OUT_SIZE, OUT_SIZE, false, Image.FORMAT_RGBA8)
		canvas.blend_rect(cropped, Rect2i(0, 0, nw, nh), Vector2i((OUT_SIZE - nw) / 2, (OUT_SIZE - nh) / 2))
		var out_name: String = JOBS[src]
		canvas.save_png(ProjectSettings.globalize_path(OUT_DIR + out_name))
		print("SAVED %s (%dx%d subject)" % [out_name, nw, nh])
	print("OK")
	quit()

func _near_white(c: Color) -> bool:
	return (1.0 - c.r) + (1.0 - c.g) + (1.0 - c.b) < WHITE_TOL

# 从四边出发的泛洪填充：只清除与边缘连通的白色区域，主体内部的白色高光保留
func _remove_white_bg(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue := PackedInt32Array()
	for x in w:
		for y in [0, h - 1]:
			if _near_white(img.get_pixel(x, y)):
				queue.append(y * w + x)
	for y in h:
		for x in [0, w - 1]:
			if _near_white(img.get_pixel(x, y)):
				queue.append(y * w + x)
	var head := 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var px: int = idx % w
		var py: int = idx / w
		var c := img.get_pixel(px, py)
		c.a = 0.0
		img.set_pixel(px, py, c)
		for dx in [-1, 1]:
			var nx: int = px + dx
			if nx >= 0 and nx < w:
				var nidx: int = py * w + nx
				if visited[nidx] == 0 and _near_white(img.get_pixel(nx, py)):
					queue.append(nidx)
		for dy in [-1, 1]:
			var ny: int = py + dy
			if ny >= 0 and ny < h:
				var nidx: int = ny * w + px
				if visited[nidx] == 0 and _near_white(img.get_pixel(px, ny)):
					queue.append(nidx)

func _content_rect(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				if x < minx:
					minx = x
				if x > maxx:
					maxx = x
				if y < miny:
					miny = y
				if y > maxy:
					maxy = y
	if maxx < 0:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
