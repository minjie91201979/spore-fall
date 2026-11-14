extends CanvasLayer
class_name SettingsPanel
# 系统设置面板：攻击自动瞄准开关 + 画质档，标题页 / 剧情暂停 / 生存 HUD 共用。
# 自己管理暂停状态：打开时暂停并记录原状态，关闭时还原（暂停菜单里打开不会把游戏放跑）。

signal closed

var _auto_btn: Button
var _quality_btn: Button
var _was_paused: bool = false

static func open_from(host: Node) -> SettingsPanel:
	var tree := host.get_tree()
	var panel := SettingsPanel.new()
	tree.root.add_child(panel)   # 挂在 root 上，不随场景切换漏掉
	panel.open()
	return panel

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时按钮照样能点
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.03, 0.8)
	add_child(dim)
	var frame := ColorRect.new()
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -260.0
	frame.offset_right = 260.0
	frame.offset_top = -190.0
	frame.offset_bottom = 190.0
	frame.color = Color(0.035, 0.055, 0.068, 0.97)
	add_child(frame)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24.0
	box.offset_right = -24.0
	box.offset_top = 18.0
	box.offset_bottom = -18.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	box.add_child(MenuChrome.label("系 统 设 置", 26, Color(0.16, 0.85, 0.8)))

	# —— 自动瞄准 ——
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 16)
	auto_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var auto_label := MenuChrome.label("攻击自动瞄准", 18, Color(0.82, 0.9, 0.91))
	auto_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_row.add_child(auto_label)
	_auto_btn = MenuChrome.primary_button("开 启")
	_auto_btn.custom_minimum_size = Vector2(112, 44)
	_auto_btn.pressed.connect(_on_auto_pressed)
	auto_row.add_child(_auto_btn)
	box.add_child(auto_row)
	var hint := MenuChrome.label("开：自动锁定最近敌人　　关：朝最后移动方向射击", 13, Color(0.55, 0.68, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	# —— 画质档 ——
	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 16)
	q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var q_label := MenuChrome.label("画质档", 18, Color(0.82, 0.9, 0.91))
	q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_row.add_child(q_label)
	_quality_btn = MenuChrome.ghost_button("高")
	_quality_btn.custom_minimum_size = Vector2(112, 44)
	_quality_btn.pressed.connect(_on_quality_pressed)
	q_row.add_child(_quality_btn)
	box.add_child(q_row)

	var close_btn := MenuChrome.ghost_button("关 闭")
	close_btn.pressed.connect(close)
	box.add_child(close_btn)
	Settings.auto_aim_changed.connect(_refresh_auto)
	EventBus.quality_changed.connect(_refresh_quality)

func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_refresh_auto(Settings.auto_aim)
	_refresh_quality(Quality.level)

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	Sfx.play("ui_blip")
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _on_auto_pressed() -> void:
	Settings.toggle_auto_aim()
	Sfx.play("ui_blip")

func _on_quality_pressed() -> void:
	Quality.cycle()
	Sfx.play("ui_blip")

func _refresh_auto(enabled: bool) -> void:
	if not is_instance_valid(_auto_btn):
		return
	_auto_btn.text = "开 启" if enabled else "关 闭"
	_auto_btn.add_theme_color_override("font_color", Color(0.02, 0.08, 0.09) if enabled else Color(0.82, 0.9, 0.91))
	var base := Color(0.16, 0.85, 0.8) if enabled else Color(0.22, 0.29, 0.31)
	_auto_btn.add_theme_stylebox_override("normal", _fill(base, 10))
	_auto_btn.add_theme_stylebox_override("hover", _fill(base.lightened(0.12), 10))
	_auto_btn.add_theme_stylebox_override("pressed", _fill(base.darkened(0.12), 10))

func _refresh_quality(level: int) -> void:
	if is_instance_valid(_quality_btn):
		_quality_btn.text = Quality.LEVEL_NAMES[clampi(level, 0, 2)]

func _fill(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb
