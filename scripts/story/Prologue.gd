extends Node2D
# 序章「雨夜抵达」：关卡岗亭到第3检疫所的一条辅道。
# 只投放漫游孢、疾走孢、肿胀孢；弹药有限，关内不弹三选一。

const WALKER: EnemyStats = preload("res://assets/data/enemy_walker.tres")
const RUNNER: EnemyStats = preload("res://assets/data/enemy_runner.tres")
const BRUTE: EnemyStats = preload("res://assets/data/enemy_brute.tres")
const PICKUP: PackedScene = preload("res://scenes/world/Pickup.tscn")
const PILLAR: PackedScene = preload("res://scenes/world/Obstacle.tscn")

const SPAWN := Vector2(-740, 140)
const DOOR := Vector2(790, 110)

var _player: CharacterBody2D
var _session: StorySession
var _camera: Camera2D
var _black: ColorRect
var _date: Label
var _first_walker: Node2D
var _held: Array[Node] = []
var _blocks: Array[Dictionary] = []
var _seen: Dictionary = {}
var _token: int = 0
var _cutscene: bool = true
var _cut_time: float = 0.0
var _intro_done: bool = false
var _left_road: bool = false
var _road_nag: bool = false
var _line_queue: Array = []
var _first_down: bool = false
var _brute_line: bool = false
var _cyan_line: bool = false
var _finished: bool = false

func _ready() -> void:
	StoryState.in_safehouse = false
	GameState.begin_story()
	GameState.objective_text = ""
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.control_mode = 2
	_player.visible = false
	_player.position = Vector2(-740, 360)
	_player.flashlight.visible = false
	if StoryState.carry_loadout:
		_player.ammo = StoryState.departure_ammo
		_player.health = clampf(StoryState.departure_health, 1.0, _player.max_health)
		GameState.crystals = StoryState.departure_crystals
		StoryState.herbs = StoryState.departure_herbs
	else:
		_player.ammo = 24
		_player.health = _player.max_health
		GameState.crystals = 0
	_camera = $Camera2D
	_camera.hold_follow = true
	_camera.hold_target = Vector2(-280, 80)
	_camera.global_position = _camera.hold_target
	_build_world()
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	_session.gameplay_unlocked = false
	GameState.story_failed.connect(func() -> void:
		_cutscene = false
		_finished = true
		_token += 1
	)
	_spawn_cast()
	_wire_props()
	Sfx.start_bgm()
	Sfx.set_bgm_db(-22.0)
	_opening()

func _process(delta: float) -> void:
	if _cutscene:
		_cut_time += delta
		return
	if _finished or _player.is_dead:
		return
	_note_names()
	_check_radio()
	_check_first_blood()
	_check_brute()
	_check_cyan()
	if _player.global_position.distance_to(DOOR) < 52.0:
		_complete()

func _unhandled_input(event: InputEvent) -> void:
	if not _cutscene or _cut_time < 2.0:
		return
	var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")
	if event is InputEventMouseButton and event.pressed:
		skip = true
	if event is InputEventScreenTouch and event.pressed:
		skip = true
	if skip:
		_finish_cutscene()
		get_viewport().set_input_as_handled()

func _opening() -> void:
	var token := _token
	await get_tree().create_timer(0.8, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	var fade := create_tween()
	fade.set_ignore_time_scale(true)
	fade.tween_property(_black, "color:a", 0.0, 2.0)
	await get_tree().create_timer(2.2, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	var zoom := create_tween()
	zoom.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	zoom.tween_property(_camera, "zoom", Vector2(1.08, 1.08), 2.4)
	await get_tree().create_timer(2.6, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	Juice.add_trauma(0.2)
	Sfx.play("hit", 0.45, -6.0)
	await get_tree().create_timer(0.45, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	_player.position = Vector2(-740, 340)
	_player.visible = true
	var walk := create_tween()
	walk.tween_property(_player, "position", SPAWN, 3.2)
	await get_tree().create_timer(0.9, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	_player.flashlight.visible = true
	_player.flashlight.rotation = deg_to_rad(-50.0)
	var sweep := create_tween()
	sweep.tween_property(_player.flashlight, "rotation", deg_to_rad(35.0), 0.7)
	sweep.tween_property(_player.flashlight, "rotation", 0.0, 0.35)
	await get_tree().create_timer(2.4, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	_date.visible = true
	_date.modulate.a = 0.0
	var date_tw := create_tween()
	date_tw.tween_property(_date, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(2.6, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	_finish_cutscene()

func _finish_cutscene() -> void:
	if not _cutscene:
		return
	_cutscene = false
	_token += 1
	_player.position = SPAWN
	_player.visible = true
	_player.flashlight.visible = true
	_player.flashlight.rotation = 0.0
	_camera.hold_follow = false
	_camera.zoom = Vector2.ONE
	_black.color.a = 0.0
	_date.visible = false
	for e in _held:
		if is_instance_valid(e):
			e.set_physics_process(true)
	GameState.objective_text = StoryText.OBJECTIVE_GATE
	Sfx.play("pickup", 1.15, -10.0)
	_session.gameplay_unlocked = true
	_player.control_mode = 0

func _complete() -> void:
	if _finished:
		return
	_finished = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	StoryState.chapter_kills = GameState.kill_count
	StoryState.carry_loadout = false
	if StoryState.replaying:
		StoryState.pending_arrival = false
	else:
		StoryState.capture(_player)
		StoryState.prologue_complete = true
		StoryState.arrival_played = false
		StoryState.pending_arrival = true
		StoryState.pending_death_line = false
	get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)

func _check_radio() -> void:
	var near_road := _player.global_position.distance_to(Vector2(-40, 40)) < 180.0
	var near_first := false
	if _first_walker and is_instance_valid(_first_walker) and _first_walker.get("active"):
		near_first = _player.global_position.distance_to(_first_walker.global_position) < 220.0
	if _intro_done and not near_road:
		_left_road = true
	if not _intro_done and (near_road or near_first):
		_intro_done = true
		if StoryState.radio_contacted:
			_say(StoryText.road_again())
		else:
			StoryState.radio_contacted = true
			_say(StoryText.intro(), true)
		return
	if _intro_done and near_road and _left_road and not _road_nag:
		_road_nag = true
		_say(StoryText.road_again())

func _check_first_blood() -> void:
	if _first_down or _first_walker == null or not is_instance_valid(_first_walker):
		return
	if _first_walker.get("active"):
		return
	_first_down = true
	_say(StoryText.after_first_walker())

func _check_brute() -> void:
	if _brute_line:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.get("active") or e.get("stats") == null:
			continue
		if not str(e.stats.display_name).contains("肿胀孢"):
			continue
		if _player.global_position.distance_to(e.global_position) < 300.0:
			_brute_line = true
			_say(StoryText.on_brute())
			return

func _check_cyan() -> void:
	if _cyan_line or _player.global_position.x < 500.0:
		return
	_cyan_line = true
	_say(StoryText.on_cyan())

func _say(lines: Array, intro: bool = false) -> void:
	if _session.dialogue.active or _session._busy_line:
		_line_queue.append(lines)
		return
	_session.say(lines, intro, _drain_lines)

func _drain_lines() -> void:
	if _line_queue.is_empty() or _finished:
		return
	var next: Array = _line_queue.pop_front()
	_session.say(next, false, _drain_lines)

func _note_names() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.get("active") or e.get("stats") == null:
			continue
		if _player.global_position.distance_to(e.global_position) > 240.0:
			continue
		var who := str(e.stats.display_name)
		if _seen.has(who):
			continue
		_seen[who] = true
		_session._toast(who)

func _spawn_cast() -> void:
	_spawn(WALKER, Vector2(-70, -130))
	_spawn(WALKER, Vector2(90, -150))
	_first_walker = _spawn(WALKER, Vector2(-180, 110))
	_spawn(RUNNER, Vector2(140, 120))
	_spawn(WALKER, Vector2(500, 150))
	_spawn(BRUTE, Vector2(680, 80))

func _spawn(stats: EnemyStats, pos: Vector2) -> Node2D:
	var pool: Node = $EnemyPool
	var e: Node2D = pool.acquire(self)
	e.configure(stats)
	e.global_position = pos
	e.set_physics_process(false)
	_held.append(e)
	return e

func _wire_props() -> void:
	var window := StoryWorld.interactable(self, Vector2(-548, 120), StoryText.PROMPT_NEAR)
	window.interacted.connect(func() -> void: _say(StoryText.window_lines()))
	var sheet := StoryWorld.interactable(self, Vector2(-640, 175), StoryText.PROMPT_NEAR)
	sheet.interacted.connect(_on_log)
	_ammo_box(Vector2(-470, 165), 12)

func _on_log() -> void:
	var first := not StoryState.has_file("gate_log")
	_session.open_file("《关卡值班记录》", StoryText.GATE_LOG)
	if first:
		StoryState.add_file("gate_log")
		_session._toast("获得文件　《关卡值班记录》")
		_session.reader.closed.connect(func() -> void:
			_say(StoryText.file_line())
		, CONNECT_ONE_SHOT)

func _ammo_box(pos: Vector2, amount: int) -> void:
	var pk: Node2D = PICKUP.instantiate()
	pk.kind = "ammo"
	pk.ammo_amount = amount
	pk.persistent = true
	pk.position = pos
	add_child(pk)

func _build_world() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 2, Color(0.45, 0.52, 0.58))
	_wall(Vector2(-860, 40), Vector2(40, 860))
	_wall(Vector2(860, 20), Vector2(40, 680))
	_wall(Vector2(0, -310), Vector2(1740, 36))
	_wall(Vector2(160, 236), Vector2(1400, 32))
	_wall(Vector2(-700, 430), Vector2(320, 32))
	_wall(Vector2(-530, 330), Vector2(28, 200))
	_wall(Vector2(-620, 40), Vector2(130, 96), Color(0.18, 0.22, 0.26))
	_wall(Vector2(-20, -230), Vector2(580, 28))
	_wall(Vector2(-310, -140), Vector2(28, 200))
	_wall(Vector2(270, -140), Vector2(28, 200))
	_wall(Vector2(-20, -46), Vector2(580, 28))
	StoryWorld.bake($NavigationRegion2D, _blocks)
	var pillar: Node2D = PILLAR.instantiate()
	pillar.position = Vector2(600, 155)
	add_child(pillar)
	StoryWorld.add_patch(self, Vector2(-560, 55), Vector2(36, 22), Color(0.45, 0.7, 0.72, 0.85))
	for i in 8:
		StoryWorld.add_patch(self, Vector2(-420 + i * 110.0, 198), Vector2(70, 8), Color(0.72, 0.58, 0.16, 0.9))
	StoryWorld.add_patch(self, Vector2(-200, 120), Vector2(90, 36), Color(0.12, 0.28, 0.32, 0.45))
	StoryWorld.add_patch(self, Vector2(420, 90), Vector2(70, 28), Color(0.1, 0.26, 0.3, 0.4))
	StoryWorld.add_light(self, Vector2(790, 70), Color(0.25, 0.9, 0.82), 2.2)
	StoryWorld.add_patch(self, Vector2(790, 70), Vector2(18, 28), Color(0.3, 0.95, 0.88))
	var rain_layer := $RainLayer
	var rain := RainOverlay.new()
	rain_layer.add_child(rain)
	var curtain := CanvasLayer.new()
	curtain.layer = 12
	add_child(curtain)
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0, 0, 0, 1)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.add_child(_black)
	_date = Label.new()
	_date.text = StoryText.DATE_LINE
	_date.anchor_left = 0.5
	_date.anchor_right = 0.5
	_date.offset_left = -220.0
	_date.offset_right = 220.0
	_date.offset_top = 78.0
	_date.offset_bottom = 110.0
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.add_theme_font_size_override("font_size", 16)
	_date.add_theme_color_override("font_color", Color(0.75, 0.9, 0.88))
	_date.visible = false
	curtain.add_child(_date)

func _wall(center: Vector2, size: Vector2, color: Color = Color(0.13, 0.16, 0.2)) -> void:
	StoryWorld.add_wall(self, center, size, color)
	_blocks.append({"center": center, "size": size})
