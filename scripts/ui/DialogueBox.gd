extends CanvasLayer
class_name DialogueBox
# 底部字幕。点一下或按空格 / E / Esc 进下一句，不另做立绘。

signal finished
signal line_shown(line: Dictionary)

var active: bool = false
var _lines: Array = []
var _index: int = 0
var _lock: float = 0.0
var _panel: Panel
var _speaker: Label
var _body: Label

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -420.0
	_panel.offset_right = 420.0
	_panel.offset_top = -168.0
	_panel.offset_bottom = -28.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.05, 0.9)
	style.border_color = Color(0.16, 0.85, 0.8, 0.7)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	_speaker = Label.new()
	_speaker.position = Vector2(18, 10)
	_speaker.add_theme_font_size_override("font_size", 14)
	_speaker.add_theme_color_override("font_color", Color(0.45, 0.9, 0.86))
	_panel.add_child(_speaker)
	_body = Label.new()
	_body.position = Vector2(18, 40)
	_body.size = Vector2(780, 90)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Color(0.9, 0.95, 0.94))
	_panel.add_child(_body)
	_panel.visible = false

func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta

func play(lines: Array, lock_sec: float = 0.0) -> void:
	_lines = lines
	_index = 0
	_lock = lock_sec
	active = true
	_show_current()

func _show_current() -> void:
	if _index >= _lines.size():
		active = false
		_panel.visible = false
		finished.emit()
		return
	var entry: Dictionary = _lines[_index]
	_speaker.text = str(entry.get("speaker", ""))
	_body.text = str(entry.get("text", ""))
	_panel.visible = true
	Sfx.play("ui_blip", randf_range(0.92, 1.08))
	line_shown.emit(entry)

func _input(event: InputEvent) -> void:
	if not active:
		return
	var advance := false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		advance = true
	elif event is InputEventMouseButton and event.pressed:
		advance = true
	elif event is InputEventScreenTouch and event.pressed:
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _lock > 0.0:
		return
	_index += 1
	_show_current()
