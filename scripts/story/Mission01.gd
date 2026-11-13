extends Node2D
const MissionKit = preload("res://scripts/story/MissionKit.gd")
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 任务一「所谓微量」：东堤外街、堤下通道、观测站泄漏管廊。
# 霰弹放在翻倒的市政巡逻车里，毒雾只在泄漏点出现一次。

const WALKER: EnemyStats = preload("res://assets/data/enemy_walker.tres")
const RUNNER: EnemyStats = preload("res://assets/data/enemy_runner.tres")
const LURKER: EnemyStats = preload("res://assets/data/enemy_lurker.tres")
const MIASMA: EnemyStats = preload("res://assets/data/enemy_miasma.tres")

const AMMO_CAR := 16
const AMMO_DUTY := 12
const AMMO_RETURN := 20

var evidence_done: bool = false
var _player: CharacterBody2D
var _session: StorySession
var _kit: MissionKit
var _pass_door: StaticBody2D
var _pipe_door: StaticBody2D
var _failed: bool = false
var _left_spawn: bool = false
var _leak_on: bool = false
var _return_on: bool = false
var _car_line: bool = false
var _green_line: bool = false
var _duty_line: bool = false

func _ready() -> void:
	StoryState.in_safehouse = false
	StoryState.active_mission = "m1"
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(-760, 150)
	_player.ammo = StoryState.ammo
	_player.health = clampf(StoryState.health, 1.0, _player.max_health)
	_player.control_mode = 0
	evidence_done = StoryState.has_file("leak_note")
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	_kit = MissionKit.new()
	add_child(_kit)
	_kit.setup(self, _player, _session)
	_build()
	_wire()
	_spawn_opening()
	if StoryState.station_pass:
		_open_doors()
	GameState.objective_text = "目标　核查东堤培养观测站"
	StoryState.refresh_keys()
	GameState.story_failed.connect(_on_failed)
	GameState.weapon_acquired.connect(_on_weapon)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-22.0)
	if not StoryState.briefing_done:
		StoryState.briefing_done = true
		_kit.say(StoryCopy.m1_depart())

func _process(delta: float) -> void:
	if _failed or _player.is_dead:
		return
	var pos := _player.global_position
	if pos.x > -560.0:
		_left_spawn = true
	_kit.note_combat(_left_spawn and pos.x < -680.0)
	if not _car_line and pos.distance_to(Vector2(-520, 150)) < 150.0:
		_car_line = true
		_kit.say(StoryCopy.m1_car())
	if not _leak_on and pos.x > 560.0 and pos.y < 30.0:
		trigger_leak()
	if not _green_line and pos.distance_to(Vector2(700, -30)) < 90.0:
		_green_line = true
		_kit.say(StoryCopy.m1_green())
	if evidence_done and not _return_on and pos.x < 480.0 and pos.y > 40.0:
		trigger_return()
	if _left_spawn and pos.x < -730.0 and pos.y > 80.0 and pos.y < 230.0:
		finish_mission()

func trigger_leak() -> void:
	if _leak_on:
		return
	_leak_on = true
	GameState.objective_text = "目标　在泄漏点取证"
	_kit.spawn(MIASMA, Vector2(660, -20), "leak")
	_kit.spawn(WALKER, Vector2(760, 0), "leak")
	_kit.spawn(WALKER, Vector2(620, -70), "leak")

func trigger_return() -> void:
	if _return_on:
		return
	_return_on = true
	GameState.objective_text = "目标　返回第3检疫所正压库"
	_kit.say(StoryCopy.m1_ambush())
	_kit.spawn(RUNNER, Vector2(-280, 120))
	_kit.spawn(RUNNER, Vector2(-140, 200))

func finish_mission() -> void:
	if _failed or _player.is_dead:
		return
	if evidence_done:
		_succeed()
	else:
		_retreat()

func take_evidence() -> void:
	if evidence_done and StoryState.has_file("leak_note"):
		_kit.read_file("leak_note")
		return
	evidence_done = true
	_kit.read_file("leak_note")
	_kit.say(StoryCopy.m1_evidence())
	GameState.objective_text = "目标　返回第3检疫所正压库"

func _succeed() -> void:
	if _failed:
		return
	_failed = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	StoryState.chapter_kills = GameState.kill_count
	if StoryState.replaying:
		StoryState.pending_chapter = "m1"
		StoryState.pending_arrival = false
		StoryState.returned_live = false
	else:
		StoryState.capture(_player)
		StoryState.mark_mission("m1")
		StoryState.pending_chapter = "m1"
		StoryState.returned_live = false
		StoryState.write_save()
	get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)

func _retreat() -> void:
	if _failed:
		return
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

func _on_weapon(id: String) -> void:
	if id == "shotgun":
		_kit.say(StoryCopy.m1_shotgun())

func _on_pass() -> void:
	if StoryState.station_pass:
		_open_doors()
		return
	StoryState.grant_key("station")
	_kit.toast("观测站通行证")
	_kit.say(StoryCopy.m1_pass())
	_open_doors()
	GameState.objective_text = "目标　进入观测站内室"

func _on_door(which: String) -> void:
	if not StoryState.station_pass:
		_kit.toast("门禁需要观测站通行证")
		return
	_open_doors()
	if which == "duty" and not _duty_line:
		_duty_line = true
		_kit.say(StoryCopy.m1_duty())

func _open_doors() -> void:
	if is_instance_valid(_pass_door):
		_pass_door.queue_free()
		_pass_door = null
	if is_instance_valid(_pipe_door):
		_pipe_door.queue_free()
		_pipe_door = null

func _on_clump() -> void:
	if StoryState.spore_clump or StoryState.spore_sold:
		return
	StoryState.grant_key("clump")
	_kit.toast("干结孢团")

func _spawn_opening() -> void:
	_kit.spawn(WALKER, Vector2(-360, 110))
	_kit.spawn(WALKER, Vector2(-250, 200))
	_kit.spawn(WALKER, Vector2(-150, 120))
	_kit.spawn(RUNNER, Vector2(-210, 170))
	_kit.spawn(LURKER, Vector2(30, 140))
	_kit.spawn(LURKER, Vector2(130, 180))
	_kit.spawn(WALKER, Vector2(300, 110))
	_kit.spawn(WALKER, Vector2(390, 190))
	_kit.spawn(RUNNER, Vector2(340, 140))

func _wire() -> void:
	_kit.place_weapon(Vector2(-490, 190), "shotgun")
	_kit.place_ammo(Vector2(-560, 130), AMMO_CAR)
	_kit.place_ammo(Vector2(730, 190), AMMO_DUTY)
	_kit.place_ammo(Vector2(-80, 150), AMMO_RETURN)
	_kit.place_heal(Vector2(760, 150))
	var duty := _kit.interact(Vector2(500, 150), StoryText.PROMPT_NEAR)
	duty.interacted.connect(func() -> void: _on_door("duty"))
	var pipe := _kit.interact(Vector2(660, 20), StoryText.PROMPT_NEAR)
	pipe.interacted.connect(func() -> void: _on_door("pipe"))
	var corpse := _kit.interact(Vector2(420, 200), StoryText.PROMPT_NEAR)
	corpse.interacted.connect(_on_pass)
	var notice := _kit.interact(Vector2(620, 170), StoryText.PROMPT_NEAR)
	notice.interacted.connect(func() -> void: _kit.read_file("leak_notice"))
	var board := _kit.interact(Vector2(600, -40), StoryText.PROMPT_NEAR)
	board.interacted.connect(func() -> void: _kit.read_file("pipe_note"))
	var leak := _kit.interact(Vector2(760, -90), StoryText.PROMPT_NEAR)
	leak.interacted.connect(take_evidence)
	if not StoryState.spore_clump and not StoryState.spore_sold:
		var clump := _kit.interact(Vector2(250, 210), "干结孢团")
		clump.interacted.connect(_on_clump)

func _build() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 2, Color(0.42, 0.5, 0.56))
	_kit.wall(Vector2(-20, 280), Vector2(1720, 32))
	_kit.wall(Vector2(-840, 150), Vector2(32, 280))
	_kit.wall(Vector2(840, 40), Vector2(32, 500))
	_kit.wall(Vector2(-200, 20), Vector2(1240, 32))
	_kit.wall(Vector2(460, 20), Vector2(80, 32))
	_kit.wall(Vector2(715, 20), Vector2(36, 32))
	_kit.wall(Vector2(680, -170), Vector2(360, 32))
	_kit.wall(Vector2(500, 70), Vector2(32, 90))
	_pass_door = _kit.wall(Vector2(500, 150), Vector2(32, 56), Color(0.2, 0.28, 0.3))
	_kit.wall(Vector2(500, 230), Vector2(32, 90))
	_kit.wall(Vector2(560, -70), Vector2(32, 180))
	_pipe_door = _kit.wall(Vector2(660, 20), Vector2(80, 32), Color(0.18, 0.26, 0.28))
	_kit.wall(Vector2(780, 20), Vector2(100, 32))
	_kit.wall(Vector2(80, 70), Vector2(160, 28))
	_kit.wall(Vector2(80, 230), Vector2(180, 28))
	_kit.wall(Vector2(-520, 150), Vector2(78, 34), Color(0.22, 0.18, 0.14))
	_kit.bake($NavigationRegion2D)
	for i in 7:
		StoryWorld.add_patch(self, Vector2(-680 + i * 90.0, 248), Vector2(64, 8), Color(0.72, 0.58, 0.16, 0.9))
	StoryWorld.add_patch(self, Vector2(-520, 150), Vector2(90, 40), Color(0.28, 0.2, 0.12, 0.95))
	StoryWorld.add_patch(self, Vector2(700, -24), Vector2(180, 22), Color(0.15, 0.75, 0.48, 0.55))
	var spray := StoryWorld.add_patch(self, Vector2(700, -24), Vector2(28, 70), Color(0.2, 0.9, 0.55, 0.7))
	var tw := create_tween().set_loops()
	tw.tween_property(spray, "modulate:a", 0.35, 0.7)
	tw.tween_property(spray, "modulate:a", 1.0, 0.7)
	StoryWorld.add_light(self, Vector2(-760, 80), Color(0.25, 0.9, 0.82), 1.8)
	StoryWorld.add_patch(self, Vector2(-760, 80), Vector2(16, 26), Color(0.3, 0.95, 0.88))
	StoryWorld.add_light(self, Vector2(760, -80), Color(0.2, 0.85, 0.45), 1.4)
	var ring := StoryWorld.add_patch(self, Vector2(820, 40), Vector2(18, 18), Color(0.2, 0.8, 0.7, 0.9))
	ring.z_index = 1
