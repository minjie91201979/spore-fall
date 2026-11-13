extends CanvasLayer
class_name StoryDeath
# 剧情倒下。不打开生存结算，不写最高分。

signal to_safehouse
signal to_title

var active: bool = false

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("story_death")
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.04, 0.78)
	add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -220.0
	box.offset_right = 220.0
	box.offset_top = -120.0
	box.offset_bottom = 120.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(MenuChrome.label("你 倒 下 了", 32, Color(0.2, 0.95, 0.9)))
	var home := MenuChrome.primary_button("回到安全屋")
	home.pressed.connect(func() -> void:
		active = false
		to_safehouse.emit()
	)
	box.add_child(home)
	var back := MenuChrome.ghost_button("返回标题")
	back.pressed.connect(func() -> void:
		active = false
		to_title.emit()
	)
	box.add_child(back)

func present() -> void:
	active = true
	visible = true
	modulate_self(0.0)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	for child in get_children():
		if child is CanvasItem:
			tw.tween_property(child, "modulate:a", 1.0, 0.25)

func modulate_self(alpha: float) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = alpha
