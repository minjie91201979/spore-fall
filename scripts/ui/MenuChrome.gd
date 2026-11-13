extends RefCounted
class_name MenuChrome
# 标题页同色的按钮和底。新菜单不另起一套亮色界面。

const BG := Color(0.0235294, 0.0392157, 0.0509804, 1)
const CYAN := Color(0.156863, 0.85098, 0.8, 1)
const DIM := Color(0.494118, 0.603922, 0.631373, 1)

static func shell(host: Control) -> VBoxContainer:
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	var spores := Control.new()
	spores.set_script(load("res://scripts/ui/SporeField.gd"))
	spores.set_anchors_preset(Control.PRESET_FULL_RECT)
	spores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(spores)
	var box := VBoxContainer.new()
	box.name = "Center"
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -230.0
	box.offset_right = 230.0
	box.offset_top = -280.0
	box.offset_bottom = 280.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	host.add_child(box)
	return box

static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.02, 0.08, 0.09))
	b.add_theme_stylebox_override("normal", _fill(Color(0.156863, 0.85098, 0.8), 10))
	b.add_theme_stylebox_override("hover", _fill(Color(0.247, 0.925, 0.874), 10))
	b.add_theme_stylebox_override("pressed", _fill(Color(0.118, 0.706, 0.667), 10))
	b.add_theme_stylebox_override("disabled", _fill(Color(0.12, 0.28, 0.28, 0.45), 10))
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.8, 0.8, 0.55))
	return b

static func ghost_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 42)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.792, 0.875, 0.882))
	b.add_theme_stylebox_override("normal", _ghost(Color(0.055, 0.082, 0.102, 0.82)))
	b.add_theme_stylebox_override("hover", _ghost(Color(0.102, 0.153, 0.18, 0.92)))
	b.add_theme_stylebox_override("pressed", _ghost(Color(0.102, 0.153, 0.18, 0.92)))
	b.add_theme_stylebox_override("disabled", _ghost(Color(0.04, 0.05, 0.06, 0.5)))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.52, 0.6))
	return b

static func _fill(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_right = radius
	s.corner_radius_bottom_left = radius
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _ghost(color: Color) -> StyleBoxFlat:
	var s := _fill(color, 10)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.18, 0.267, 0.302)
	return s
