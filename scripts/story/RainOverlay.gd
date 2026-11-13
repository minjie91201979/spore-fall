extends Control
class_name RainOverlay
# 序章雨线。屏幕空间的短竖线，不做成暴雨电影。

var _drops: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 70:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.4)))

func _process(delta: float) -> void:
	var h := size.y if size.y > 1.0 else get_viewport_rect().size.y
	for i in _drops.size():
		var d := _drops[i]
		d.y += delta * d.z * 0.45
		if d.y > 1.15:
			d.y = -0.05
			d.x = randf()
		_drops[i] = d
	queue_redraw()

func _draw() -> void:
	var s := size if size.x > 1.0 else get_viewport_rect().size
	for d in _drops:
		var p := Vector2(d.x * s.x, d.y * s.y)
		draw_line(p, p + Vector2(6, 16), Color(0.65, 0.8, 0.85, 0.28), 1.0)
