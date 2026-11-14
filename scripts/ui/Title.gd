extends Control
# 标题界面：剧情 / 生存两个入口。
# 主页不再展示最高分；有记录时只在桌面端用一行暗字带过。
# 画质、系统设置和退出仍留在这一页。

@onready var story_btn: Button = $Center/StoryButton
@onready var survival_btn: Button = $Center/SurvivalButton
@onready var quality_btn: Button = $Center/QualityButton
@onready var quit_btn: Button = $Center/QuitButton
@onready var story_hint: Label = $Center/StoryHint
@onready var survival_hint: Label = $Center/SurvivalHint
@onready var hint_touch: Label = $Hints/TouchHint
@onready var hint_pc: Label = $Hints/PcHint
var settings_btn: Button

func _ready() -> void:
	StoryState.load_disk()
	story_btn.pressed.connect(_open_story)
	survival_btn.pressed.connect(_open_survival)
	quality_btn.pressed.connect(_cycle_quality)
	quit_btn.pressed.connect(_quit)
	# 系统设置按钮插在「画质」之后，样式与同列 ghost 按钮一致
	settings_btn = MenuChrome.ghost_button("系 统 设 置")
	settings_btn.custom_minimum_size = Vector2(260, 42)
	settings_btn.add_theme_font_size_override("font_size", 15)
	settings_btn.focus_mode = Control.FOCUS_NONE
	var center := quality_btn.get_parent()
	center.add_child(settings_btn)
	center.move_child(settings_btn, quality_btn.get_index() + 1)
	settings_btn.pressed.connect(_open_settings)
	EventBus.quality_changed.connect(_on_quality_changed)
	_refresh_quality()
	_refresh_summaries()
	var mobile := OS.has_feature("mobile")
	hint_touch.visible = mobile
	hint_pc.visible = not mobile
	story_btn.focus_neighbor_bottom = story_btn.get_path_to(survival_btn)
	survival_btn.focus_neighbor_top = survival_btn.get_path_to(story_btn)
	story_btn.grab_focus()
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.45)

func _open_story() -> void:
	_leave("res://scenes/ui/StorySelect.tscn")

func _open_survival() -> void:
	_leave("res://scenes/ui/SurvivalReady.tscn")

func _leave(path: String) -> void:
	if story_btn.disabled:
		return
	story_btn.disabled = true
	survival_btn.disabled = true
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file(path)

func _cycle_quality() -> void:
	Quality.cycle()

func _open_settings() -> void:
	SettingsPanel.open_from(self)

func _on_quality_changed(_lv: int) -> void:
	_refresh_quality()

func _refresh_quality() -> void:
	quality_btn.text = "画质　%s" % Quality.LEVEL_NAMES[Quality.level]

func _refresh_summaries() -> void:
	# 手机竖向空间紧，两行缩略只留给桌面
	if OS.has_feature("mobile"):
		story_hint.visible = false
		survival_hint.visible = false
		return
	if StoryState.has_save:
		story_hint.text = "调查进行中　·　最近：%s" % StoryState.recent_name()
		story_hint.visible = true
	else:
		story_hint.visible = false
	var career := Career.title_line()
	if GameState.best_score > 0 or career != "":
		var parts: PackedStringArray = []
		if GameState.best_score > 0:
			parts.append("最高分　%06d" % GameState.best_score)
		if career != "":
			parts.append(career)
		survival_hint.text = "　·　".join(parts)
		survival_hint.visible = true
	else:
		survival_hint.visible = false

func _quit() -> void:
	get_tree().quit()
