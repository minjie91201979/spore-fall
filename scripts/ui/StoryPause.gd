extends CanvasLayer
class_name StoryPause
# 剧情暂停。安全屋可以直接回标题；外面要先确认，因为终端以外的进度不落盘。

signal resumed
signal to_title

var active: bool = false
var _confirming: bool = false
var _box: VBoxContainer
var _confirm: VBoxContainer

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.03, 0.72)
	add_child(dim)
	_box = VBoxContainer.new()
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -200.0
	_box.offset_right = 200.0
	_box.offset_top = -140.0
	_box.offset_bottom = 140.0
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	_box.add_child(MenuChrome.label("暂　停", 28, Color(0.16, 0.85, 0.8)))
	var cont := MenuChrome.primary_button("继 续")
	cont.pressed.connect(close_pause)
	_box.add_child(cont)
	var quality := MenuChrome.ghost_button("画 质")
	quality.pressed.connect(func() -> void:
		Quality.cycle()
		quality.text = "画质　%s" % Quality.LEVEL_NAMES[Quality.level]
	)
	_box.add_child(quality)
	var settings := MenuChrome.ghost_button("系统设置")
	settings.pressed.connect(func() -> void:
		SettingsPanel.open_from(self)
	)
	_box.add_child(settings)
	var back := MenuChrome.ghost_button("返回标题")
	back.pressed.connect(_on_title)
	_box.add_child(back)
	_confirm = VBoxContainer.new()
	_confirm.anchor_left = 0.5
	_confirm.anchor_right = 0.5
	_confirm.anchor_top = 0.5
	_confirm.anchor_bottom = 0.5
	_confirm.offset_left = -260.0
	_confirm.offset_right = 260.0
	_confirm.offset_top = -120.0
	_confirm.offset_bottom = 140.0
	_confirm.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.add_theme_constant_override("separation", 10)
	_confirm.visible = false
	add_child(_confirm)
	_confirm.add_child(MenuChrome.label("未在安全屋保存的进度将会丢失。确定返回标题吗？", 16, Color(0.85, 0.9, 0.9)))
	var yes := MenuChrome.primary_button("确 定")
	yes.pressed.connect(func() -> void:
		active = false
		get_tree().paused = false
		to_title.emit()
	)
	_confirm.add_child(yes)
	var no := MenuChrome.ghost_button("取 消")
	no.pressed.connect(func() -> void:
		_confirming = false
		_confirm.visible = false
		_box.visible = true
	)
	_confirm.add_child(no)

func open_pause() -> void:
	active = true
	_confirming = false
	_box.visible = true
	_confirm.visible = false
	visible = true
	get_tree().paused = true
	var touch := get_tree().get_first_node_in_group("touch_controls")
	if touch and touch.has_method("reset_input"):
		touch.reset_input()

func close_pause() -> void:
	active = false
	_confirming = false
	visible = false
	get_tree().paused = false
	resumed.emit()

func _on_title() -> void:
	if StoryState.in_safehouse:
		active = false
		get_tree().paused = false
		to_title.emit()
		return
	_confirming = true
	_box.visible = false
	_confirm.visible = true
