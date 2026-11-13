extends CanvasLayer
class_name FileReader
# 全文阅读。关掉之后才把控制交还。

signal closed

var active: bool = false
var _title: Label
var _body: RichTextLabel
var _dim: ColorRect

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.02, 0.03, 0.82)
	add_child(_dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -240.0
	panel.offset_bottom = 240.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.06, 0.96)
	style.border_color = Color(0.16, 0.85, 0.8, 0.55)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_title = Label.new()
	_title.position = Vector2(24, 16)
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.9))
	panel.add_child(_title)
	_body = RichTextLabel.new()
	_body.position = Vector2(24, 56)
	_body.size = Vector2(632, 340)
	_body.scroll_active = true
	_body.bbcode_enabled = false
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_color_override("default_color", Color(0.86, 0.9, 0.88))
	panel.add_child(_body)
	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.position = Vector2(560, 410)
	close_btn.pressed.connect(close_reader)
	panel.add_child(close_btn)
	visible = false

func open_file(title: String, body: String, marks: PackedStringArray = PackedStringArray()) -> void:
	_title.text = title
	var shown := body
	if marks.is_empty():
		_body.bbcode_enabled = false
		_body.text = shown
	else:
		_body.bbcode_enabled = true
		for mark in marks:
			if mark == "":
				continue
			if shown.contains(mark):
				shown = shown.replace(mark, "[color=#7ef0e0]%s[/color]" % mark)
			else:
				shown += "\n\n[color=#7ef0e0]%s[/color]" % mark
		_body.text = shown
	active = true
	visible = true

func close_reader() -> void:
	if not active:
		return
	active = false
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_reader()
