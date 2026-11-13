extends Node2D
const MissionKit = preload("res://scripts/story/MissionKit.gd")
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 任务四「向下生长」：B2 入口平台 → 中央栈道（韩朔被困）→ 武器柜走廊（激光枪）
# → 观察廊（裴衡抉择：翠障剂 / 焚毁）→ 分巢腔 Boss 战。

const WALKER: EnemyStats = preload("res://assets/data/enemy_walker.tres")
const SPITTER: EnemyStats = preload("res://assets/data/enemy_spitter.tres")
const SPRAYER: EnemyStats = preload("res://assets/data/enemy_sprayer.tres")
const BRUTE: EnemyStats = preload("res://assets/data/enemy_brute.tres")
const SPLITTER: EnemyStats = preload("res://assets/data/enemy_splitter.tres")
const BOSS: EnemyStats = preload("res://assets/data/enemy_boss.tres")

const AMMO_ENTRANCE := 16
const AMMO_HALL := 20

var _player: CharacterBody2D
var _session: StorySession
var _kit: MissionKit
var _cam: Camera2D
var _han: Sprite2D
var _pei_light: PointLight2D
var _failed: bool = false
var _entered_walk: bool = false
var _han_trapped: bool = false
var _han_rescued: bool = false
var _laser_acquired: bool = false
var _at_gallery: bool = false
var _choice_made: bool = false
var _boss_spawned: bool = false
var _weapon_triggered: bool = false
var _boss_door: StaticBody2D
var _token: int = 0

func _ready() -> void:
	StoryState.in_safehouse = false
	StoryState.active_mission = "m4"
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(-820, 150)
	_player.ammo = StoryState.ammo
	_player.health = clampf(StoryState.health, 1.0, _player.max_health)
	_player.control_mode = 0
	_cam = $Camera2D
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	_kit = MissionKit.new()
	add_child(_kit)
	_kit.setup(self, _player, _session)
	_build()
	_wire()
	_spawn_entrance()
	GameState.objective_text = "目标　穿过 B2 入口，前往中央栈道"
	StoryState.refresh_keys()
	GameState.story_failed.connect(_on_failed)
	GameState.weapon_acquired.connect(_on_weapon)
	EventBus.boss_defeated.connect(_on_boss_down)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-22.0)
	if not StoryState.briefing_done:
		StoryState.briefing_done = true
		_kit.say(StoryCopy.m4_depart())

func _process(_delta: float) -> void:
	if _failed or _player.is_dead:
		return
	var pos := _player.global_position
	_kit.note_combat(false)
	_kit.hold_zone("entrance", "x", -480.0, true)
	_kit.hold_zone("walk", "x", 60.0, true)
	_kit.hold_zone("weapon", "x", 380.0, true)
	if not _entered_walk and pos.x > -500.0:
		_entered_walk = true
		GameState.objective_text = "目标　清除栈道孢群，解救韩朔"
		_trigger_trapped()
	if _han_trapped and not _han_rescued:
		if _walk_clear() and pos.distance_to(_han.global_position) < 130.0:
			_rescue_han()
	if not _at_gallery and pos.x > 380.0 and pos.y > 70.0 and pos.y < 230.0:
		_at_gallery = true
		_begin_gallery()
	if not _weapon_triggered and pos.x > 80.0 and pos.x < 360.0:
		_weapon_triggered = true
		_trigger_weapon_room()
	if _choice_made and not _boss_spawned and pos.x > 760.0:
		_spawn_boss()

func finish_mission() -> void:
	if _failed or _player.is_dead:
		return
	_succeed()

func _spawn_entrance() -> void:
	_kit.spawn(SPITTER, Vector2(-560, 110), "entrance")
	_kit.spawn(SPITTER, Vector2(-520, 190), "entrance")
	_kit.spawn(WALKER, Vector2(-640, 150), "entrance")
	_kit.spawn(WALKER, Vector2(-480, 120), "entrance")
	_kit.spawn(WALKER, Vector2(-600, 200), "entrance")

func _trigger_trapped() -> void:
	if _han_trapped:
		return
	_han_trapped = true
	Juice.add_trauma(0.35)
	Sfx.play("hit", 0.5, -6.0)
	_kit.spawn(SPRAYER, Vector2(-300, 110), "walk")
	_kit.spawn(SPRAYER, Vector2(-260, 200), "walk")
	_kit.spawn(SPITTER, Vector2(-200, 150), "walk")
	_kit.say(StoryCopy.m4_trapped())

func _walk_clear() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.get("active"):
			continue
		if str(e.get_meta("zone", "")) == "walk":
			return false
	return true

func _rescue_han() -> void:
	if _han_rescued:
		return
	_han_rescued = true
	_token += 1
	var token := _token
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	_cam.hold_follow = true
	_cam.hold_target = _han.global_position
	await get_tree().create_timer(1.0, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	if _han:
		var tw := create_tween()
		tw.tween_property(_han, "position", Vector2(-120, 160), 1.4)
	_kit.say(StoryCopy.m4_rescue(), func() -> void:
		if _failed or not is_inside_tree():
			return
		_cam.hold_follow = false
		_session.gameplay_unlocked = true
		_player.control_mode = 0
		GameState.objective_text = "目标　取武器柜走廊的激光枪，前往观察廊"
	)

func _on_laser() -> void:
	if _laser_acquired:
		return
	_laser_acquired = true
	_kit.say(StoryCopy.m4_laser())

func _trigger_weapon_room() -> void:
	_kit.spawn(BRUTE, Vector2(180, 120), "weapon")
	_kit.spawn(SPLITTER, Vector2(300, 190), "weapon")

func _begin_gallery() -> void:
	if _at_gallery:
		return
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	_cam.hold_follow = true
	_cam.hold_target = Vector2(470, 150)
	if _pei_light:
		var lit := create_tween()
		lit.tween_property(_pei_light, "energy", 1.8, 0.6)
	await get_tree().create_timer(0.6, true, false, true).timeout
	if not is_inside_tree():
		return
	_kit.say(StoryCopy.m4_pei_intro(), func() -> void:
		if _failed or not is_inside_tree():
			return
		_cam.hold_follow = false
		_session.gameplay_unlocked = true
		_player.control_mode = 0
		GameState.objective_text = "目标　在观察廊做出抉择"
	)

func _make_choice(which: String) -> void:
	if _choice_made:
		return
	_choice_made = true
	StoryState.pei_choice = which
	if which == "A":
		_kit.say(StoryCopy.m4_choice_a())
	else:
		_kit.say(StoryCopy.m4_choice_b())
	GameState.objective_text = "目标　进入分巢腔，击溃母巢孢"
	var a := _find_choice("翠障剂")
	var b := _find_choice("焚毁")
	if is_instance_valid(a):
		a.enabled = false
	if is_instance_valid(b):
		b.enabled = false
	_open_boss_door()

func _open_boss_door() -> void:
	if is_instance_valid(_boss_door):
		_boss_door.queue_free()
		_boss_door = null

func _find_choice(label: String) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and str(node.prompt).contains(label):
			return node
	return null

func _spawn_boss() -> void:
	if _boss_spawned:
		return
	_boss_spawned = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	var clutch: EnemyStats = BOSS.duplicate()
	clutch.display_name = "母巢孢（分巢形态）"
	clutch.max_health = 2400.0
	var boss: Node2D = _kit.spawn(clutch, Vector2(940, 150), "boss")
	GameState.boss_active = true
	EventBus.boss_spawned.emit(clutch.display_name, float(boss.get("max_health")))
	Juice.add_trauma(0.5)
	Sfx.play("hurt", 0.5, 4.0)
	await get_tree().create_timer(0.8, true, false, true).timeout
	if not is_inside_tree():
		return
	_kit.say(StoryCopy.m4_boss(), func() -> void:
		if _failed or not is_inside_tree():
			return
		_session.gameplay_unlocked = true
		_player.control_mode = 0
		GameState.objective_text = "目标　击溃分巢形态母巢孢"
	)

func _on_boss_down(_name: String) -> void:
	if _failed or not _boss_spawned:
		return
	_succeed()

func _on_weapon(id: String) -> void:
	if id == "laser":
		_on_laser()

func _on_failed() -> void:
	_failed = true
	_token += 1

func _succeed() -> void:
	_failed = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	StoryState.chapter_kills = GameState.kill_count
	_kit.say(StoryCopy.m4_win(), func() -> void:
		if StoryState.replaying:
			StoryState.pending_chapter = "m4"
			StoryState.returned_live = false
			get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)
			return
		StoryState.capture(_player)
		StoryState.mark_mission("m4")
		StoryState.pending_chapter = "m4"
		StoryState.returned_live = false
		StoryState.write_save()
		get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)
	)

func _wire() -> void:
	_kit.place_weapon(Vector2(220, 110), "laser")
	_kit.place_ammo(Vector2(-700, 160), AMMO_ENTRANCE)
	_kit.place_ammo(Vector2(120, 210), AMMO_HALL)
	_kit.place_heal(Vector2(300, 180))
	var log := _kit.interact(Vector2(-120, 90), StoryText.PROMPT_NEAR)
	log.interacted.connect(func() -> void: _kit.read_file("descent_log"))
	var choice_a := _kit.interact(Vector2(420, 200), "部署翠障剂")
	choice_a.interacted.connect(func() -> void: _make_choice("A"))
	var choice_b := _kit.interact(Vector2(540, 200), "焚毁培养层")
	choice_b.interacted.connect(func() -> void: _make_choice("B"))
	var peek := _kit.interact(Vector2(470, 90), StoryText.PROMPT_NEAR)
	peek.interacted.connect(func() -> void:
		if not _choice_made:
			_kit.say(StoryCopy.m4_skip_choice())
	)

func _build() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 2, Color(0.3, 0.36, 0.42))
	# 外墙
	_kit.wall(Vector2(80, 56), Vector2(2080, 28))
	_kit.wall(Vector2(80, 246), Vector2(2080, 28))
	_kit.wall(Vector2(-940, 150), Vector2(28, 190))
	_kit.wall(Vector2(1080, 150), Vector2(28, 190))
	# 入口 → 栈道 隔墙（留门口 y 120~180）
	_kit.wall(Vector2(-500, 92), Vector2(28, 70))
	_kit.wall(Vector2(-500, 210), Vector2(28, 70))
	# 栈道 → 武器廊 隔墙（门口 y 120~180）
	_kit.wall(Vector2(60, 92), Vector2(28, 70))
	_kit.wall(Vector2(60, 210), Vector2(28, 70))
	# 武器廊 → 观察廊 隔墙
	_kit.wall(Vector2(380, 92), Vector2(28, 70))
	_kit.wall(Vector2(380, 210), Vector2(28, 70))
	# 观察廊 → 分巢腔 隔墙（抉择前封死，抉择后开启）
	_boss_door = _kit.wall(Vector2(700, 150), Vector2(28, 190), Color(0.2, 0.32, 0.3))
	_kit.bake($NavigationRegion2D)
	StoryWorld.add_patch(self, Vector2(-300, 150), Vector2(40, 16), Color(0.95, 0.55, 0.2, 0.8))   # 韩朔被困处
	StoryWorld.add_patch(self, Vector2(220, 110), Vector2(28, 40), Color(0.45, 0.18, 0.12, 0.9))      # 激光枪
	StoryWorld.add_patch(self, Vector2(940, 150), Vector2(120, 80), Color(0.55, 0.2, 0.5, 0.35))       # 分巢腔
	_han = Sprite2D.new()
	_han.texture = load("res://assets/characters/player.png")
	_han.scale = Vector2(0.2, 0.2)
	_han.modulate = Color(0.95, 0.55, 0.2)
	_han.position = Vector2(-300, 150)
	add_child(_han)
	_pei_light = StoryWorld.add_light(self, Vector2(470, 120), Color(0.75, 0.9, 0.95), 0.0)
	StoryWorld.add_light(self, Vector2(-820, 80), Color(0.25, 0.9, 0.82), 1.3)
