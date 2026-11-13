extends Control
# 生存准备页。进战场的淡出和 Arena.start_run 与原来的「开始游戏」一致。

func _ready() -> void:
	var box := MenuChrome.shell(self)
	box.add_child(MenuChrome.label("无 尽 生 存 · E N D L E S S", 12, Color(0.298, 0.686, 0.678, 0.9)))
	box.add_child(MenuChrome.label("生 存 游 戏", 36, MenuChrome.CYAN))
	box.add_child(MenuChrome.label("在被孢子吞没的城市里，活到最后一刻", 15, Color(0.725, 0.796, 0.812)))
	var best := MenuChrome.label("", 14, MenuChrome.DIM)
	best.name = "BestLabel"
	if GameState.best_score > 0:
		best.text = "最高分　%06d" % GameState.best_score
	else:
		best.visible = false
	box.add_child(best)
	var career := MenuChrome.label(Career.title_line(), 13, Color(0.5, 0.64, 0.68))
	career.name = "CareerLabel"
	career.visible = career.text != ""
	box.add_child(career)
	var enter := MenuChrome.primary_button("进 入 战 场")
	enter.name = "EnterButton"
	enter.pressed.connect(_enter)
	box.add_child(enter)
	var back := MenuChrome.ghost_button("返 回")
	back.name = "BackButton"
	back.pressed.connect(_back)
	box.add_child(back)
	enter.grab_focus()
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _enter() -> void:
	Sfx.play("levelup", 0.9, -3.0)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/world/Arena.tscn")

func _back() -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
