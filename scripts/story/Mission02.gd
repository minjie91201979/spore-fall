extends Node2D
const MissionKit = preload("res://scripts/story/MissionKit.gd")
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 任务二「还在线上的人」：封锁巷和市政巡查站的双电闸。
# 韩朔只做脚本出场和断后，不进对象池，也不会被打死。

const WALKER: EnemyStats = preload("res://assets/data/enemy_walker.tres")
const RUNNER: EnemyStats = preload("res://assets/data/enemy_runner.tres")
const LURKER: EnemyStats = preload("res://assets/data/enemy_lurker.tres")
const SPLITTER: EnemyStats = preload("res://assets/data/enemy_splitter.tres")
const SPITTER: EnemyStats = preload("res://assets/data/enemy_spitter.tres")

const AMMO_HALL := 16
const AMMO_POWER := 16
const LOCKER_AMMO := 20

var han_met: bool = false
var _player: CharacterBody2D
var _session: StorySession
var _kit: MissionKit
var _shutter: StaticBody2D
var _shutter_vis: Polygon2D
var _han: Sprite2D
var _letter: Interactable
var _failed: bool = false
var _switch_a: bool = false
var _switch_b: bool = false
var _half_said: bool = false
var _met_lines: bool = false
var _retreat_on: bool = false
var _wave2: bool = false
var _retreat_t: float = 0.0
var _left_exit: bool = false
var _front_line: bool = false

func _ready() -> void:
	StoryState.in_safehouse = false
	StoryState.active_mission = "m2"
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(0, 760)
	_player.ammo = StoryState.ammo
	_player.health = clampf(StoryState.health, 1.0, _player.max_health)
	_player.control_mode = 0
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	_kit = MissionKit.new()
	add_child(_kit)
	_kit.setup(self, _player, _session)
	_build()
	_wire()
	_spawn_opening()
	GameState.objective_text = "目标　前往市政巡查站"
	StoryState.refresh_keys()
	GameState.story_failed.connect(_on_failed)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-22.0)
	if not StoryState.briefing_done:
		StoryState.briefing_done = true
		_kit.say(StoryCopy.m2_depart())

func _process(delta: float) -> void:
	if _failed or _player.is_dead:
		return
	var pos := _player.global_position
	if pos.y < 560.0:
		_left_exit = true
	_kit.note_combat(_left_exit and han_met and pos.y > 640.0)
	if not _front_line and pos.y < 430.0 and pos.y > 200.0:
		_front_line = true
		GameState.objective_text = "目标　恢复闸门电源"
		_kit.say(StoryCopy.m2_shutter())
	if _retreat_on and not _wave2:
		_retreat_t += delta
		if _retreat_t >= 8.0:
			_wave2 = true
			_spawn_wave(false)
	if han_met and _left_exit and pos.y > 700.0 and absf(pos.x) < 140.0:
		finish_mission()

func finish_mission() -> void:
	if _failed or _player.is_dead:
		return
	if han_met:
		_succeed()
	else:
		_retreat()

func _succeed() -> void:
	_failed = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	StoryState.chapter_kills = GameState.kill_count
	if StoryState.replaying:
		StoryState.pending_chapter = "m2"
		StoryState.returned_live = false
	else:
		StoryState.capture(_player)
		StoryState.mark_mission("m2")
		StoryState.pending_chapter = "m2"
		StoryState.returned_live = false
		StoryState.write_save()
	get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)

func _retreat() -> void:
	_failed = true
	_player.control_mode = 2
	if StoryState.replaying:
		StoryState.pending_chapter = ""
		StoryState.returned_live = false
	else:
		StoryState.capture(_player)
		StoryState.returned_live = true
		StoryState.pending_chapter = ""
	get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)

func _on_failed() -> void:
	_failed = true

func _on_key() -> void:
	if StoryState.breaker_key:
		return
	StoryState.grant_key("breaker")
	_kit.toast("电闸钥匙")

func _on_switch(which: String) -> void:
	if not StoryState.breaker_key:
		_kit.toast("电闸钥匙在挂板上")
		return
	if which == "a":
		if _switch_a:
			return
		_switch_a = true
	else:
		if _switch_b:
			return
		_switch_b = true
	Sfx.play("pickup", 0.7, -8.0)
	if _switch_a and _switch_b:
		_raise_shutter()
		return
	if not _half_said:
		_half_said = true
		_kit.say(StoryCopy.m2_half(not _switch_b))
		_kit.spawn(RUNNER, Vector2(0, 400))

func _raise_shutter() -> void:
	_player.control_mode = 2
	_session.gameplay_unlocked = false
	if is_instance_valid(_shutter):
		_shutter.collision_layer = 0
		var shape := _shutter.get_node_or_null("CollisionShape2D")
		if shape:
			shape.disabled = true
	Juice.add_trauma(0.15)
	if _shutter_vis:
		var tw := create_tween()
		tw.tween_property(_shutter_vis, "position:y", 40.0, 1.4)
	var timer := get_tree().create_timer(1.1, true, false, true)
	timer.timeout.connect(func() -> void:
		if not is_inside_tree() or _failed:
			return
		_step_han()
	)

func _step_han() -> void:
	if _han:
		var tw := create_tween()
		tw.tween_property(_han, "position", Vector2(0, 130), 0.8)
	var timer := get_tree().create_timer(0.9, true, false, true)
	timer.timeout.connect(func() -> void:
		if not is_inside_tree() or _failed:
			return
		han_met = true
		_met_lines = true
		if _letter:
			_letter.enabled = true
		GameState.objective_text = "目标　与韩朔会合，从后院撤离"
		_session.gameplay_unlocked = true
		_kit.say(StoryCopy.m2_meet(), _begin_retreat)
	)

func _begin_retreat() -> void:
	if _failed or _retreat_on:
		return
	_retreat_on = true
	_retreat_t = 0.0
	if _han:
		var tw := create_tween()
		tw.tween_property(_han, "position", Vector2(90, 680), 1.6)
	_kit.say(StoryCopy.m2_retreat())
	_spawn_wave(true)

func trigger_retreat() -> void:
	if not han_met:
		_raise_shutter()
		return
	_begin_retreat()

func _spawn_wave(first: bool) -> void:
	if first:
		var posted := SPITTER.duplicate()
		posted.move_speed = 28.0
		_kit.spawn(posted, Vector2(-120, 520))
		_kit.spawn(posted, Vector2(120, 520))
		_kit.spawn(RUNNER, Vector2(-20, 580))
		_kit.spawn(WALKER, Vector2(40, 500))
	else:
		_kit.spawn(RUNNER, Vector2(20, 540))
		_kit.spawn(WALKER, Vector2(-60, 620))
		_kit.spawn(WALKER, Vector2(50, 640))

func _on_locker() -> void:
	_kit.ask_code(StoryCopy.LOCKER_CODE, "储物柜　工号", _grant_locker)

func _grant_locker() -> void:
	_player.heal(25.0)
	_player.ammo += LOCKER_AMMO
	EventBus.pickup_collected.emit("ammo", LOCKER_AMMO)
	_kit.toast("医疗包　·　弹药 +%d" % LOCKER_AMMO)

func _spawn_opening() -> void:
	_kit.spawn(RUNNER, Vector2(-40, 520))
	_kit.spawn(RUNNER, Vector2(50, 480))
	_kit.spawn(LURKER, Vector2(0, 360))
	_kit.spawn(WALKER, Vector2(-70, 500))
	_kit.spawn(WALKER, Vector2(70, 540))
	_kit.spawn(SPLITTER, Vector2(20, 280))
	_kit.spawn(WALKER, Vector2(-60, 360))
	_kit.spawn(WALKER, Vector2(70, 370))
	_kit.spawn(LURKER, Vector2(320, 320))
	_kit.spawn(WALKER, Vector2(-280, 300))
	_kit.spawn(WALKER, Vector2(-380, 340))
	_kit.spawn(RUNNER, Vector2(-320, 260))

func _wire() -> void:
	_kit.place_weapon(Vector2(80, 100), "firerifle")
	_kit.place_ammo(Vector2(60, 360), AMMO_HALL)
	_kit.place_ammo(Vector2(400, 280), AMMO_POWER)
	var key := _kit.interact(Vector2(120, 340), StoryText.PROMPT_NEAR)
	key.interacted.connect(_on_key)
	var log := _kit.interact(Vector2(-70, 340), StoryText.PROMPT_NEAR)
	log.interacted.connect(func() -> void: _kit.read_file("patrol_log"))
	var sw_a := _kit.interact(Vector2(360, 300), StoryText.PROMPT_NEAR)
	sw_a.interacted.connect(func() -> void: _on_switch("a"))
	var sw_b := _kit.interact(Vector2(-340, 300), StoryText.PROMPT_NEAR)
	sw_b.interacted.connect(func() -> void: _on_switch("b"))
	var locker := _kit.interact(Vector2(-300, 350), "储物柜　4471")
	locker.interacted.connect(_on_locker)
	_letter = _kit.interact(Vector2(-30, 90), StoryText.PROMPT_NEAR)
	_letter.enabled = false
	_letter.interacted.connect(func() -> void: _kit.read_file("qingchao_letter"))

func _build() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 2, Color(0.4, 0.46, 0.52))
	_kit.wall(Vector2(0, 30), Vector2(400, 28))
	_kit.wall(Vector2(-190, 120), Vector2(28, 180))
	_kit.wall(Vector2(190, 120), Vector2(28, 180))
	_shutter = _kit.wall(Vector2(0, 178), Vector2(380, 26), Color(0.32, 0.34, 0.36))
	_shutter_vis = _shutter.get_node_or_null("Polygon2D") as Polygon2D
	_kit.wall(Vector2(-190, 230), Vector2(28, 50))
	_kit.wall(Vector2(-190, 380), Vector2(28, 70))
	_kit.wall(Vector2(190, 230), Vector2(28, 50))
	_kit.wall(Vector2(190, 380), Vector2(28, 70))
	_kit.wall(Vector2(-320, 210), Vector2(260, 28))
	_kit.wall(Vector2(-450, 310), Vector2(28, 200))
	_kit.wall(Vector2(-325, 418), Vector2(310, 28))
	_kit.wall(Vector2(320, 210), Vector2(260, 28))
	_kit.wall(Vector2(450, 310), Vector2(28, 200))
	_kit.wall(Vector2(325, 418), Vector2(310, 28))
	_kit.wall(Vector2(-110, 430), Vector2(140, 28))
	_kit.wall(Vector2(110, 430), Vector2(140, 28))
	_kit.wall(Vector2(0, 310), Vector2(96, 32), Color(0.24, 0.2, 0.16))
	_kit.wall(Vector2(-160, 630), Vector2(28, 360))
	_kit.wall(Vector2(160, 630), Vector2(28, 360))
	_kit.wall(Vector2(0, 810), Vector2(340, 28))
	_kit.bake($NavigationRegion2D)
	_han = Sprite2D.new()
	_han.texture = load("res://assets/characters/player.png")
	_han.scale = Vector2(0.2, 0.2)
	_han.modulate = Color(0.95, 0.55, 0.2)
	_han.position = Vector2(0, 90)
	add_child(_han)
	StoryWorld.add_light(self, Vector2(0, 760), Color(0.25, 0.9, 0.82), 1.6)
	StoryWorld.add_patch(self, Vector2(0, 760), Vector2(16, 24), Color(0.3, 0.95, 0.88))
	StoryWorld.add_patch(self, Vector2(-120, 520), Vector2(70, 16), Color(0.35, 0.32, 0.28))
	StoryWorld.add_patch(self, Vector2(120, 520), Vector2(70, 16), Color(0.35, 0.32, 0.28))
	StoryWorld.add_patch(self, Vector2(130, 250), Vector2(36, 14), Color(0.45, 0.32, 0.16))
