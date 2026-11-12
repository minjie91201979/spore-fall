extends Control
# 标题界面：游戏入口。承担三件事——
# 1) 建立基调（孢城 / 末世孢子 / 冷青色）；
# 2) 给出操作说明（PC 与手机各一行，避免测试者上手发懵）；
# 3) 开局前可切画质（低端机先降档再进场，比进场后卡了再找开关合理）。

@onready var start_btn: Button = $Center/StartButton
@onready var quality_btn: Button = $Center/QualityButton
@onready var quit_btn: Button = $Center/QuitButton
@onready var best_label: Label = $Center/BestLabel
@onready var hint_touch: Label = $Hints/TouchHint

func _ready() -> void:
	start_btn.pressed.connect(_start)
	quality_btn.pressed.connect(_cycle_quality)
	quit_btn.pressed.connect(_quit)
	EventBus.quality_changed.connect(_on_quality_changed)
	_refresh_quality()
	_refresh_best()
	# 手机才显示触控提示，桌面显示键鼠提示
	hint_touch.visible = OS.has_feature("mobile")
	# 入场：整页淡入 + 标题轻微上浮
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.45)

func _unhandled_input(event: InputEvent) -> void:
	if start_btn.disabled:
		return
	if event.is_action_pressed("ui_accept"):
		_start()

func _start() -> void:
	if start_btn.disabled:
		return
	start_btn.disabled = true
	Sfx.play("levelup", 0.9, -3.0)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/world/Arena.tscn")

func _cycle_quality() -> void:
	Quality.cycle()

func _on_quality_changed(_lv: int) -> void:
	_refresh_quality()

func _refresh_quality() -> void:
	quality_btn.text = "画质　%s" % Quality.LEVEL_NAMES[Quality.level]

func _refresh_best() -> void:
	if GameState.best_score > 0:
		best_label.text = "最高分　%06d" % GameState.best_score
		best_label.visible = true
	else:
		best_label.visible = false

func _quit() -> void:
	get_tree().quit()
