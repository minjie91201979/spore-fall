extends CanvasLayer
class_name WaveCard
# 「进入下一波 / WAVE 2」过渡提示卡。
# 显示时暂停整棵树（get_tree().paused = true），自身 PROCESS_MODE_ALWAYS 维持
# 倒计时与按钮响应；5 秒自动继续，或点「继续」立即进入下一波。

signal continued

var active: bool = false
var _countdown: float = 5.0
var _cd_label: Label

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("wave_card")

func present(kicker: String, title: String, subtitle: String) -> void:
	for c in get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.03, 0.04, 0.74)
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
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(MenuChrome.label(kicker, 14, Color(0.45, 0.85, 0.8)))
	box.add_child(MenuChrome.label(title, 30, Color(0.95, 0.28, 0.55)))
	box.add_child(MenuChrome.label(subtitle, 13, Color(0.7, 0.82, 0.86)))
	var cont := MenuChrome.primary_button("继 续")
	cont.pressed.connect(_on_continue)
	box.add_child(cont)
	_cd_label = MenuChrome.label("5", 12, Color(0.5, 0.62, 0.64))
	box.add_child(_cd_label)
	active = true
	visible = true
	dim.modulate.a = 0.0
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.35)
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	_countdown = 5.0

func _process(delta: float) -> void:
	if not active:
		return
	_countdown -= delta
	if _cd_label:
		_cd_label.text = "%d" % maxi(0, int(ceil(_countdown)))
	if _countdown <= 0.0:
		_on_continue()

func _on_continue() -> void:
	if not active:
		return
	active = false
	visible = false
	for c in get_children():
		c.queue_free()
	continued.emit()
