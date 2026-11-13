extends Control
# 剧情选章。这一期只有序章可进，任务一到五保持锁定文案。

var _confirm: Control

func _ready() -> void:
	StoryState.load_disk()
	var box := MenuChrome.shell(self)
	box.add_child(MenuChrome.label("选 择 章 节", 32, MenuChrome.CYAN))
	box.add_child(MenuChrome.label(
		"已通关 %d/5　·　最近存档 %s" % [StoryState.missions_cleared(), StoryState.save_stamp()],
		13, MenuChrome.DIM))
	var cont := MenuChrome.primary_button("继 续 调 查")
	cont.disabled = not StoryState.has_save
	cont.pressed.connect(_continue)
	box.add_child(cont)
	for chapter in StoryText.CHAPTERS:
		var unlocked: bool = str(chapter.id) == "prologue"
		var title := str(chapter.title)
		if unlocked and StoryState.prologue_complete:
			title += "　已完成"
		elif not unlocked:
			title = str(chapter.locked)
		var btn := MenuChrome.ghost_button(title)
		btn.disabled = not unlocked
		if unlocked:
			btn.pressed.connect(_play_prologue)
		box.add_child(btn)
	if StoryState.prologue_complete:
		box.add_child(MenuChrome.label("重玩不会覆盖你的主存档", 12, MenuChrome.DIM))
	else:
		box.add_child(MenuChrome.label("沿黄漆辅道抵达第3检疫所正压库并进入。", 12, MenuChrome.DIM))
	var restart := MenuChrome.ghost_button("从 头 开 始")
	restart.pressed.connect(_ask_clear)
	box.add_child(restart)
	var back := MenuChrome.ghost_button("返 回")
	back.pressed.connect(_back)
	box.add_child(back)
	_build_confirm()
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _confirm.visible:
			_confirm.visible = false
		else:
			_back()
		get_viewport().set_input_as_handled()

func _continue() -> void:
	if not StoryState.has_save:
		return
	_leave(StoryState.SAFEHOUSE_SCENE)

func _play_prologue() -> void:
	StoryState.replaying = StoryState.prologue_complete
	StoryState.carry_loadout = false
	StoryState.pending_arrival = false
	StoryState.pending_death_line = false
	_leave(StoryState.PROLOGUE_SCENE)

func _ask_clear() -> void:
	_confirm.visible = true

func _do_clear() -> void:
	StoryState.clear_progress()
	StoryState.replaying = false
	StoryState.carry_loadout = false
	_leave(StoryState.PROLOGUE_SCENE)

func _back() -> void:
	_leave(StoryState.TITLE_SCENE)

func _leave(path: String) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file(path)

func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	_confirm.add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -140.0
	box.offset_bottom = 150.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_confirm.add_child(box)
	box.add_child(MenuChrome.label("清 除 调 查 进 度", 24, MenuChrome.CYAN))
	box.add_child(MenuChrome.label("这将清除当前调查进度，包括安全屋存档与关键道具。生存模式的最高分和成就不会受影响。", 14, Color(0.85, 0.9, 0.9)))
	var yes := MenuChrome.primary_button("确认清除")
	yes.pressed.connect(_do_clear)
	box.add_child(yes)
	var no := MenuChrome.ghost_button("取 消")
	no.pressed.connect(func() -> void: _confirm.visible = false)
	box.add_child(no)
