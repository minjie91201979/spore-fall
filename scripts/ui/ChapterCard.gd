extends CanvasLayer
class_name ChapterCard
# 序章结算卡。不显示生存 SCORE。

signal continued
signal to_title

var active: bool = false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func present(kicker: String, chapter: String, result: String, kills: int) -> void:
	for c in get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.03, 0.04, 0.72)
	add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -160.0
	box.offset_bottom = 160.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(MenuChrome.label(kicker, 14, Color(0.45, 0.85, 0.8)))
	box.add_child(MenuChrome.label(chapter, 28, Color(0.16, 0.85, 0.8)))
	box.add_child(MenuChrome.label(result, 16, Color(0.8, 0.88, 0.86)))
	box.add_child(MenuChrome.label("击杀　%d" % kills, 13, Color(0.5, 0.62, 0.64)))
	var cont := MenuChrome.primary_button("继 续")
	cont.pressed.connect(func() -> void:
		active = false
		visible = false
		continued.emit()
	)
	box.add_child(cont)
	var back := MenuChrome.ghost_button("返回标题")
	back.pressed.connect(func() -> void:
		active = false
		visible = false
		to_title.emit()
	)
	box.add_child(back)
	active = true
	visible = true
	dim.modulate.a = 0.0
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.35)
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
