extends CanvasLayer
class_name RadioCaption
# 路晚棠的无线电框：第一次先显示未识别频点，之后缩成角标。没有立绘。

var introduced: bool = false
var _panel: Panel
var _title: Label
var _wave: Control
var _minimized: bool = false
var _t: float = 0.0

func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Panel.new()
	_panel.position = Vector2(-280, 168)
	_panel.custom_minimum_size = Vector2(240, 64)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.07, 0.88)
	style.border_color = Color(0.2, 0.85, 0.78, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_title = Label.new()
	_title.position = Vector2(12, 8)
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.9))
	_title.text = "未识别频点"
	_panel.add_child(_title)
	_wave = Control.new()
	_wave.position = Vector2(12, 34)
	_wave.size = Vector2(210, 22)
	_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave.draw.connect(_draw_wave)
	_panel.add_child(_wave)
	_panel.visible = false

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_t += delta
	_wave.queue_redraw()

func _draw_wave() -> void:
	for i in 8:
		var h: float = 4.0 + 12.0 * absf(sin(_t * 9.0 + float(i) * 0.8))
		_wave.draw_rect(Rect2(Vector2(i * 14.0, 16.0 - h), Vector2(6, h)), Color(0.3, 0.9, 0.85, 0.85))

func play_intro() -> void:
	introduced = true
	_minimized = false
	_panel.visible = true
	_panel.position = Vector2(-280, 168)
	_panel.custom_minimum_size = Vector2(240, 64)
	_title.text = "未识别频点"
	_title.visible = true
	_wave.visible = true
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_panel, "position:x", 24.0, 0.35)
	await get_tree().create_timer(0.55, true, false, true).timeout
	if not is_inside_tree():
		return
	_title.text = "路晚棠"
	_title.modulate = Color(0.6, 1.0, 0.95)
	var flash := create_tween()
	flash.tween_property(_title, "modulate", Color.WHITE, 0.25)

func expand(title_text: String) -> void:
	if not introduced:
		introduced = true
	_minimized = false
	_panel.visible = true
	_panel.position = Vector2(24, 168)
	_panel.custom_minimum_size = Vector2(240, 64)
	_title.visible = true
	_wave.visible = true
	_title.text = title_text

func shrink() -> void:
	if not introduced:
		_panel.visible = false
		return
	_minimized = true
	_title.text = "路晚棠"
	_panel.position = Vector2(24, 168)
	_panel.custom_minimum_size = Vector2(96, 36)
	_wave.visible = false
