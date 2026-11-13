extends Node
class_name StorySession
# 剧情场景共用的字幕、无线电、死亡和暂停。不管生存 Arena。

var player: Node2D
var dialogue: DialogueBox
var radio: RadioCaption
var reader: FileReader
var chapter: ChapterCard
var death: StoryDeath
var pause_menu: StoryPause
var prompt: Label
var interact_available: bool = false
var gameplay_unlocked: bool = true
var _locks: int = 0
var _after_dialogue: Callable = Callable()
var _warned_ammo: bool = false
var _warned_health: bool = false
var _busy_line: bool = false

func mount(who: Node2D) -> void:
	player = who
	add_to_group("story_director")
	dialogue = DialogueBox.new()
	radio = RadioCaption.new()
	reader = FileReader.new()
	chapter = ChapterCard.new()
	death = StoryDeath.new()
	pause_menu = StoryPause.new()
	add_child(radio)
	add_child(dialogue)
	add_child(reader)
	add_child(pause_menu)
	add_child(chapter)
	add_child(death)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.line_shown.connect(_on_line_shown)
	reader.closed.connect(_on_reader_closed)
	death.to_safehouse.connect(_on_death_safehouse)
	death.to_title.connect(_go_title)
	pause_menu.to_title.connect(_go_title)
	chapter.to_title.connect(_go_title)
	GameState.story_failed.connect(_on_story_failed)
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	prompt = Label.new()
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -280.0
	prompt.offset_right = 280.0
	prompt.offset_top = -210.0
	prompt.offset_bottom = -180.0
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color(0.7, 0.9, 0.88))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(prompt)
	var pause_btn := Button.new()
	pause_btn.text = "暂 停"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -150.0
	pause_btn.offset_top = 64.0
	pause_btn.offset_right = -20.0
	pause_btn.offset_bottom = 100.0
	pause_btn.pressed.connect(func() -> void:
		if death.active or chapter.active or dialogue.active:
			return
		pause_menu.open_pause()
	)
	ui.add_child(pause_btn)

func _process(_delta: float) -> void:
	var near := _nearest()
	var herb := _can_herb()
	var blocked := _ui_blocking()
	interact_available = (near != null or herb) and not blocked
	if near:
		prompt.text = near.prompt
		prompt.visible = not _ui_blocking()
	elif herb:
		prompt.text = StoryText.PROMPT_USE
		prompt.visible = not _ui_blocking()
	else:
		prompt.visible = false
	if player == null or not gameplay_unlocked or _ui_blocking():
		return
	if dialogue.active:
		return
	if not _warned_ammo and not player.get("infinite_ammo") and int(player.ammo) < 8 and int(player.ammo) >= 0:
		_warned_ammo = true
		say(StoryText.low_ammo())
	elif not _warned_health and float(player.health) < float(player.max_health) * 0.3 and float(player.health) > 0.0:
		_warned_health = true
		say(StoryText.low_health())

func _unhandled_input(event: InputEvent) -> void:
	if dialogue.active or reader.active or death.active or chapter.active:
		return
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.active:
			pause_menu.close_pause()
		else:
			pause_menu.open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		try_interact()
		get_viewport().set_input_as_handled()

func try_interact() -> void:
	if _ui_blocking() or not gameplay_unlocked:
		return
	var near := _nearest()
	if near:
		near.interacted.emit()
		return
	if _can_herb():
		StoryState.herbs -= 1
		player.heal(25.0)
		Sfx.play("pickup", 0.9, -4.0)
		_toast("草药")

func say(lines: Array, intro: bool = false, done: Callable = Callable()) -> void:
	if lines.is_empty() or dialogue.active:
		if done.is_valid():
			done.call()
		return
	_busy_line = true
	_after_dialogue = done
	_push_lock()
	if intro:
		radio.play_intro()
		await get_tree().create_timer(0.7, true, false, true).timeout
		if not is_inside_tree():
			return
	elif _has_radio(lines):
		radio.expand("路晚棠")
	dialogue.play(lines, 0.15 if intro else 0.0)

func open_file(title: String, body: String) -> void:
	_push_lock()
	reader.open_file(title, body)

func show_chapter(kicker: String, chapter_name: String, result: String, kills: int, on_continue: Callable) -> void:
	_push_lock()
	chapter.continued.connect(func() -> void:
		_pop_lock()
		if on_continue.is_valid():
			on_continue.call()
	, CONNECT_ONE_SHOT)
	chapter.present(kicker, chapter_name, result, kills)

func _on_dialogue_finished() -> void:
	_busy_line = false
	radio.shrink()
	_pop_lock()
	var done := _after_dialogue
	_after_dialogue = Callable()
	if done.is_valid():
		done.call()

func _on_line_shown(entry: Dictionary) -> void:
	if bool(entry.get("radio", false)):
		radio.expand("路晚棠")

func _on_reader_closed() -> void:
	_pop_lock()

func _nearest() -> Interactable:
	if player == null:
		return null
	var best: Interactable = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Interactable:
			continue
		var it: Interactable = node
		if not it.enabled:
			continue
		var d: float = player.global_position.distance_to(it.global_position)
		if d <= it.radius and d < best_d:
			best = it
			best_d = d
	return best

func _can_herb() -> bool:
	if player == null or StoryState.herbs <= 0:
		return false
	return float(player.health) < float(player.max_health)

func _ui_blocking() -> bool:
	return dialogue.active or reader.active or death.active or chapter.active or pause_menu.active or _busy_line

func _push_lock() -> void:
	_locks += 1
	if player:
		player.control_mode = 2

func _pop_lock() -> void:
	_locks = maxi(0, _locks - 1)
	if player == null:
		return
	if _locks == 0 and gameplay_unlocked and not death.active:
		player.control_mode = 0
	else:
		player.control_mode = 2

func _has_radio(lines: Array) -> bool:
	for entry in lines:
		if bool(entry.get("radio", false)):
			return true
	return false

func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_story_toast"):
		hud.show_story_toast(text)

func _on_story_failed() -> void:
	gameplay_unlocked = false
	if player:
		player.control_mode = 2
	death.present()

func _on_death_safehouse() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	StoryState.return_from_death()

func _go_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Sfx.stop_bgm()
	StoryState.load_disk()
	get_tree().change_scene_to_file(StoryState.TITLE_SCENE)
