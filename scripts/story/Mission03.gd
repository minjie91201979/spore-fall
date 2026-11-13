extends Node2D
const MissionKit = preload("res://scripts/story/MissionKit.gd")
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 任务三「青潮的门」：外场仓库、访客走廊、培养预备室。
# 裴衡只站在观察窗后；韩朔送到侧门就离开，不进走廊。

const WALKER: EnemyStats = preload("res://assets/data/enemy_walker.tres")
const RUNNER: EnemyStats = preload("res://assets/data/enemy_runner.tres")
const MIASMA: EnemyStats = preload("res://assets/data/enemy_miasma.tres")
const SPLITTER: EnemyStats = preload("res://assets/data/enemy_splitter.tres")
const SPRAYER: EnemyStats = preload("res://assets/data/enemy_sprayer.tres")
const SPITTER: EnemyStats = preload("res://assets/data/enemy_spitter.tres")

const AMMO_BOOTH := 16
const AMMO_HALL := 20
const AMMO_PREP := 16

var _player: CharacterBody2D
var _session: StorySession
var _kit: MissionKit
var _cam: Camera2D
var _outer_door: StaticBody2D
var _airlock: StaticBody2D
var _prep_door: StaticBody2D
var _pei: Sprite2D
var _pei_light: PointLight2D
var _han: Sprite2D
var _failed: bool = false
var _armed: bool = false
var _pei_started: bool = false
var _airlock_open: bool = false
var _prep_open: bool = false
var _truth_started: bool = false
var _ruptured: bool = false
var _card_given: bool = false
var _token: int = 0

func _ready() -> void:
	StoryState.in_safehouse = false
	StoryState.active_mission = "m3"
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(-740, 150)
	_player.ammo = StoryState.ammo
	_player.health = clampf(StoryState.health, 1.0, _player.max_health)
	_player.control_mode = 0
	_card_given = StoryState.descent_card
	_cam = $Camera2D
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	_kit = MissionKit.new()
	add_child(_kit)
	_kit.setup(self, _player, _session)
	_build()
	_wire()
	_spawn_outer()
	if StoryState.visitor_pass:
		_remove_body(_outer_door)
		_outer_door = null
	GameState.objective_text = "目标　进入青潮厂区"
	StoryState.refresh_keys()
	GameState.story_failed.connect(_on_failed)
	GameState.weapon_acquired.connect(_on_weapon)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-22.0)
	_walk_han()
	if not StoryState.briefing_done:
		StoryState.briefing_done = true
		_kit.say(StoryCopy.m3_depart())

func _process(_delta: float) -> void:
	if _failed or _player.is_dead:
		return
	var pos := _player.global_position
	if pos.x > -500.0:
		_armed = true
	_kit.note_combat(_armed and pos.x < -680.0)
	_kit.hold_zone("outer", "x", -280.0, true)
	_kit.hold_zone("hall", "x", 250.0, false)
	_kit.hold_zone("prep", "y", 0.0, true)
	if not _pei_started and pos.x > -30.0 and pos.y > 90.0 and pos.y < 200.0:
		_begin_pei()
	if _prep_open and not _truth_started and pos.y < 10.0 and pos.x > 430.0:
		_begin_truth()
	if _ruptured and not _card_given and _prep_clear():
		_give_card()
	if _armed and StoryState.descent_card and pos.x < -730.0 and absf(pos.y - 150.0) < 80.0:
		finish_mission()

func finish_mission() -> void:
	if _failed or _player.is_dead:
		return
	if StoryState.descent_card:
		_succeed()
	else:
		_retreat()

func trigger_hall() -> void:
	if _airlock_open:
		return
	_airlock_open = true
	_remove_body(_airlock)
	_airlock = null
	_kit.spawn(SPLITTER, Vector2(400, 150), "hall")
	_kit.spawn(SPLITTER, Vector2(540, 190), "hall")
	_kit.spawn(SPRAYER, Vector2(480, 120), "hall")
	_kit.spawn(SPRAYER, Vector2(620, 200), "hall")
	_kit.spawn(RUNNER, Vector2(360, 200), "hall")
	_kit.spawn(RUNNER, Vector2(660, 140), "hall")

func trigger_prep() -> void:
	if _ruptured:
		return
	_ruptured = true
	Juice.add_trauma(0.45)
	Sfx.play("hit", 0.4, -6.0)
	_kit.spawn(SPRAYER, Vector2(560, -80), "prep")
	_kit.spawn(SPITTER, Vector2(480, -50), "prep")
	_kit.spawn(SPITTER, Vector2(650, -110), "prep")
	_kit.spawn(WALKER, Vector2(520, -120), "prep")
	_kit.spawn(WALKER, Vector2(640, -40), "prep")
	_kit.say(StoryCopy.m3_rupture())

func _succeed() -> void:
	_failed = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	StoryState.chapter_kills = GameState.kill_count
	if StoryState.replaying:
		StoryState.pending_chapter = "m3"
		StoryState.returned_live = false
	else:
		StoryState.capture(_player)
		StoryState.mark_mission("m3")
		StoryState.pending_chapter = "m3"
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
	_token += 1

func _on_weapon(id: String) -> void:
	if id == "flamethrower":
		_kit.say(StoryCopy.m3_flame())

func _on_pass() -> void:
	if not StoryState.visitor_pass:
		StoryState.grant_key("visitor")
		_kit.toast("访客证")
		_kit.say(StoryCopy.m3_pass())
	_remove_body(_outer_door)
	_outer_door = null
	GameState.objective_text = "目标　走访客通道"

func _on_outer_door() -> void:
	if not StoryState.visitor_pass:
		_kit.toast("门禁需要访客证")
		return
	_remove_body(_outer_door)
	_outer_door = null

func _on_prep_door() -> void:
	if _prep_open:
		return
	_kit.ask_code(StoryCopy.PREP_CODE, "预备室侧门　后四位", _open_prep)

func _open_prep() -> void:
	_prep_open = true
	_remove_body(_prep_door)
	_prep_door = null
	GameState.objective_text = "目标　听完说明，取得下行权限卡"
	_kit.say(StoryCopy.m3_code_ok())

func _on_filter() -> void:
	if StoryState.filter_core or StoryState.filter_sold:
		return
	StoryState.grant_key("filter")
	_kit.toast("未开封滤芯")

func _walk_han() -> void:
	if _han == null:
		return
	var tw := create_tween()
	tw.tween_property(_han, "position", Vector2(-520, 180), 2.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_han):
			_han.visible = false
	)

func _begin_pei() -> void:
	if _pei_started or _failed:
		return
	_pei_started = true
	var token := _token
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	_cam.hold_follow = true
	_cam.hold_target = Vector2(40, 120)
	await get_tree().create_timer(1.2, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	if _pei:
		var fade := create_tween()
		fade.tween_property(_pei, "modulate:a", 1.0, 0.8)
	if _pei_light:
		var lit := create_tween()
		lit.tween_property(_pei_light, "energy", 1.6, 0.6)
	Sfx.play("pickup", 1.4, -12.0)
	await get_tree().create_timer(0.9, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	_kit.say(StoryCopy.m3_window(), _after_window)

func _after_window() -> void:
	if _failed or not is_inside_tree():
		return
	_cam.hold_follow = false
	Juice.add_trauma(0.12)
	trigger_hall()
	_kit.say(StoryCopy.m3_airlock(), func() -> void:
		if _failed:
			return
		_session.gameplay_unlocked = true
		_player.control_mode = 0
		GameState.objective_text = "目标　打开预备室侧门"
	)

func _begin_truth() -> void:
	if _truth_started:
		return
	_truth_started = true
	_player.control_mode = 2
	_kit.say(StoryCopy.m3_truth(), func() -> void:
		if _failed or not is_inside_tree():
			return
		_player.control_mode = 0
		trigger_prep()
	)

func _prep_clear() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.get("active"):
			continue
		if str(e.get_meta("zone", "")) == "prep":
			return false
	return true

func _give_card() -> void:
	_card_given = true
	if not StoryState.descent_card:
		StoryState.grant_key("descent")
		_kit.toast("下行权限卡")
	GameState.objective_text = "目标　返回第3检疫所正压库"
	_kit.say(StoryCopy.m3_card())

func _spawn_outer() -> void:
	_kit.spawn(MIASMA, Vector2(-520, 120), "outer")
	_kit.spawn(MIASMA, Vector2(-420, 200), "outer")
	_kit.spawn(WALKER, Vector2(-600, 180), "outer")
	_kit.spawn(WALKER, Vector2(-380, 150), "outer")
	_kit.spawn(WALKER, Vector2(-470, 90), "outer")

func _remove_body(body: StaticBody2D) -> void:
	if is_instance_valid(body):
		body.queue_free()

func _wire() -> void:
	_kit.place_weapon(Vector2(700, 120), "flamethrower")
	_kit.place_ammo(Vector2(-680, 160), AMMO_BOOTH)
	_kit.place_ammo(Vector2(360, 210), AMMO_HALL)
	_kit.place_ammo(Vector2(600, -130), AMMO_PREP)
	_kit.place_heal(Vector2(460, 180))
	var booth := _kit.interact(Vector2(-650, 90), StoryText.PROMPT_NEAR)
	booth.interacted.connect(_on_pass)
	var door := _kit.interact(Vector2(-270, 150), StoryText.PROMPT_NEAR)
	door.interacted.connect(_on_outer_door)
	var shelf := _kit.interact(Vector2(300, 100), StoryText.PROMPT_NEAR)
	shelf.interacted.connect(func() -> void: _kit.read_file("stage_log"))
	var prep := _kit.interact(Vector2(520, 80), "后四位")
	prep.interacted.connect(_on_prep_door)
	var memo := _kit.interact(Vector2(500, -90), StoryText.PROMPT_NEAR)
	memo.interacted.connect(func() -> void: _kit.read_file("ethics_memo"))
	if not StoryState.filter_core and not StoryState.filter_sold:
		var filt := _kit.interact(Vector2(680, 210), "未开封滤芯")
		filt.interacted.connect(_on_filter)
	var pei_talk := _kit.interact(Vector2(40, 90), StoryText.PROMPT_NEAR)
	pei_talk.interacted.connect(_on_pei_again)

func _on_pei_again() -> void:
	if not _pei_started:
		return
	var pool := StoryCopy.PEI_WINDOW
	var idx := randi() % pool.size()
	_kit.say([StoryText.line("裴衡", pool[idx])])

func _build() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 2, Color(0.38, 0.48, 0.54))
	_kit.wall(Vector2(-800, 150), Vector2(28, 240))
	_kit.wall(Vector2(-520, 40), Vector2(560, 28))
	_kit.wall(Vector2(-520, 260), Vector2(560, 28))
	_kit.wall(Vector2(-230, 82), Vector2(28, 70))
	_outer_door = _kit.wall(Vector2(-230, 155), Vector2(28, 70), Color(0.16, 0.28, 0.3))
	_kit.wall(Vector2(-230, 228), Vector2(28, 64))
	_kit.wall(Vector2(-20, 72), Vector2(400, 24))
	_kit.wall(Vector2(-20, 210), Vector2(400, 24))
	_kit.wall(Vector2(190, 92), Vector2(90, 24))
	_airlock = _kit.wall(Vector2(190, 148), Vector2(28, 72), Color(0.15, 0.32, 0.34))
	_kit.wall(Vector2(190, 202), Vector2(90, 24))
	_kit.wall(Vector2(500, 250), Vector2(580, 28))
	_kit.wall(Vector2(790, 145), Vector2(28, 230))
	_kit.wall(Vector2(340, 40), Vector2(220, 28))
	_prep_door = _kit.wall(Vector2(520, 40), Vector2(90, 28), Color(0.2, 0.32, 0.3))
	_kit.wall(Vector2(680, 40), Vector2(200, 28))
	_kit.wall(Vector2(410, -60), Vector2(28, 200))
	_kit.wall(Vector2(730, -60), Vector2(28, 200))
	_kit.wall(Vector2(570, -160), Vector2(340, 28))
	_kit.bake($NavigationRegion2D)
	StoryWorld.add_patch(self, Vector2(0, 72), Vector2(180, 10), Color(0.75, 0.9, 0.92, 0.28))
	StoryWorld.add_patch(self, Vector2(560, -70), Vector2(36, 80), Color(0.15, 0.7, 0.45, 0.45))
	StoryWorld.add_patch(self, Vector2(700, 120), Vector2(28, 40), Color(0.45, 0.18, 0.12, 0.9))
	for i in 3:
		StoryWorld.add_patch(self, Vector2(-760 + i * 28.0, 40), Vector2(16, 16), Color(0.2, 0.75, 0.7, 0.8))
	_pei = Sprite2D.new()
	_pei.texture = load("res://assets/characters/player.png")
	_pei.scale = Vector2(0.2, 0.2)
	_pei.modulate = Color(0.82, 0.9, 0.92, 0.0)
	_pei.position = Vector2(40, 18)
	add_child(_pei)
	var glass := StoryWorld.add_patch(self, Vector2(48, 8), Vector2(6, 4), Color(1, 1, 1, 0.9))
	glass.z_index = 2
	_pei_light = StoryWorld.add_light(self, Vector2(40, 10), Color(0.75, 0.9, 0.95), 0.0)
	_han = Sprite2D.new()
	_han.texture = load("res://assets/characters/player.png")
	_han.scale = Vector2(0.2, 0.2)
	_han.modulate = Color(0.95, 0.55, 0.2)
	_han.position = Vector2(-700, 190)
	add_child(_han)
	StoryWorld.add_light(self, Vector2(-740, 80), Color(0.25, 0.9, 0.82), 1.3)
