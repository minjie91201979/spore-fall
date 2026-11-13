extends Node2D
const MissionKit = preload("res://scripts/story/MissionKit.gd")
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 任务五「把根烧掉」：翠巢主腔 → 本体 Boss 战 → 焚毁协议倒计时撤离 → 结局。

const WALKER: EnemyStats = preload("res://assets/data/enemy_walker.tres")
const RUNNER: EnemyStats = preload("res://assets/data/enemy_runner.tres")
const SPRAYER: EnemyStats = preload("res://assets/data/enemy_sprayer.tres")
const SPLITTER: EnemyStats = preload("res://assets/data/enemy_splitter.tres")
const BRUTE: EnemyStats = preload("res://assets/data/enemy_brute.tres")
const BOSS: EnemyStats = preload("res://assets/data/enemy_boss.tres")

const AMMO_DEEP := 20
const AMMO_CHAMBER := 18
const BURN_SECONDS := 50.0

var _player: CharacterBody2D
var _session: StorySession
var _kit: MissionKit
var _failed: bool = false
var _entered_deep: bool = false
var _entered_chamber: bool = false
var _boss_spawned: bool = false
var _boss_down: bool = false
var _burning: bool = false
var _burn_t: float = 0.0
var _evacuated: bool = false
var _token: int = 0

func _ready() -> void:
	StoryState.in_safehouse = false
	StoryState.active_mission = "m5"
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(-820, 150)
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
	_spawn_deep()
	GameState.objective_text = "目标　深入翠巢主腔"
	StoryState.refresh_keys()
	GameState.story_failed.connect(_on_failed)
	EventBus.boss_defeated.connect(_on_boss_down)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-22.0)
	if not StoryState.briefing_done:
		StoryState.briefing_done = true
		_kit.say(StoryCopy.m5_depart())

func _process(delta: float) -> void:
	if _failed or _player.is_dead:
		return
	var pos := _player.global_position
	_kit.note_combat(false)
	_kit.hold_zone("deep", "x", -480.0, true)
	if not _entered_deep and pos.x > -500.0:
		_entered_deep = true
		GameState.objective_text = "目标　穿过深层通道，进入主腔"
	if not _entered_chamber and pos.x > 360.0:
		_entered_chamber = true
		_trigger_boss()
	if _burning:
		_burn_t -= delta
		GameState.objective_text = "目标　撤离到上行口　·　%.0f 秒" % maxf(0.0, _burn_t)
		if _burn_t <= 0.0:
			_fail_burn()
		elif pos.x < -700.0 and absf(pos.y - 150.0) < 90.0:
			_evacuate()

func _spawn_deep() -> void:
	_kit.spawn(WALKER, Vector2(-640, 120), "deep")
	_kit.spawn(WALKER, Vector2(-600, 200), "deep")
	_kit.spawn(RUNNER, Vector2(-560, 160), "deep")
	_kit.spawn(SPRAYER, Vector2(-500, 140), "deep")
	_kit.spawn(SPLITTER, Vector2(-700, 180), "deep")

func _trigger_boss() -> void:
	if _boss_spawned:
		return
	_boss_spawned = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	var core: EnemyStats = BOSS.duplicate()
	core.display_name = "翠巢本体"
	core.max_health = 4200.0
	var boss: Node2D = _kit.spawn(core, Vector2(880, 150), "boss")
	GameState.boss_active = true
	EventBus.boss_spawned.emit(core.display_name, float(boss.get("max_health")))
	Juice.add_trauma(0.6)
	Sfx.play("hurt", 0.5, 4.0)
	await get_tree().create_timer(0.9, true, false, true).timeout
	if not is_inside_tree():
		return
	_kit.say(StoryCopy.m5_descent(), func() -> void:
		if _failed or not is_inside_tree():
			return
		_session.gameplay_unlocked = true
		_player.control_mode = 0
		GameState.objective_text = "目标　击溃翠巢本体"
	)

func _on_boss_down(_name: String) -> void:
	if _failed or _boss_down or not _boss_spawned:
		return
	_boss_down = true
	GameState.objective_text = "目标　启动焚毁协议"
	_start_burn()

func _start_burn() -> void:
	if _burning:
		return
	_burning = true
	_burn_t = BURN_SECONDS
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	_token += 1
	var token := _token
	Sfx.play("flame", 0.7, -4.0)
	Sfx.start_ambient("amb_boss")
	await get_tree().create_timer(1.0, true, false, true).timeout
	if token != _token or not is_inside_tree():
		return
	_session.gameplay_unlocked = true
	_player.control_mode = 0
	_kit.say(StoryCopy.m5_boss(), func() -> void:
		if _failed or not is_inside_tree():
			return
		_kit.say(StoryCopy.m5_burn())
	)

func _evacuate() -> void:
	if _evacuated or _failed:
		return
	_evacuated = true
	_succeed()

func _fail_burn() -> void:
	if _failed:
		return
	_failed = true
	_token += 1
	GameState.objective_text = "焚毁已启动　·　撤离失败"
	Juice.add_trauma(0.9)
	Sfx.play("hurt", 0.6, 2.0)
	await get_tree().create_timer(0.4, true, false, true).timeout
	if not is_inside_tree():
		return
	GameState.fail_story()

func _on_failed() -> void:
	_failed = true
	_token += 1

func _succeed() -> void:
	_failed = true
	_session.gameplay_unlocked = false
	_player.control_mode = 2
	StoryState.chapter_kills = GameState.kill_count
	_kit.say(StoryCopy.m5_end(), func() -> void:
		if StoryState.replaying:
			StoryState.pending_chapter = "m5"
			StoryState.returned_live = false
			get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)
			return
		StoryState.capture(_player)
		StoryState.mark_mission("m5")
		StoryState.pending_chapter = "m5"
		StoryState.returned_live = false
		StoryState.write_save()
		get_tree().change_scene_to_file(StoryState.SAFEHOUSE_SCENE)
	)

func _wire() -> void:
	_kit.place_ammo(Vector2(-660, 160), AMMO_DEEP)
	_kit.place_ammo(Vector2(560, 200), AMMO_CHAMBER)
	_kit.place_heal(Vector2(200, 180))
	var rec := _kit.interact(Vector2(120, 90), StoryText.PROMPT_NEAR)
	rec.interacted.connect(func() -> void: _kit.read_file("root_record"))
	var exit := _kit.interact(Vector2(-760, 150), "上行口")
	exit.interacted.connect(func() -> void:
		if _burning:
			_evacuate()
	)

func _build() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 2, Color(0.28, 0.3, 0.38))
	# 外墙
	_kit.wall(Vector2(80, 56), Vector2(2080, 28))
	_kit.wall(Vector2(80, 246), Vector2(2080, 28))
	_kit.wall(Vector2(-940, 150), Vector2(28, 190))
	_kit.wall(Vector2(1080, 150), Vector2(28, 190))
	# 深层通道 → 主腔 隔墙（门口 y 120~180）
	_kit.wall(Vector2(360, 92), Vector2(28, 70))
	_kit.wall(Vector2(360, 213), Vector2(28, 66))
	_kit.bake($NavigationRegion2D)
	StoryWorld.add_patch(self, Vector2(880, 150), Vector2(160, 100), Color(0.5, 0.15, 0.45, 0.4))   # 本体腔
	StoryWorld.add_patch(self, Vector2(-760, 150), Vector2(40, 40), Color(0.3, 0.95, 0.88, 0.6))        # 上行口
	StoryWorld.add_light(self, Vector2(-820, 80), Color(0.25, 0.9, 0.82), 1.3)
	StoryWorld.add_light(self, Vector2(880, 150), Color(0.7, 0.3, 0.6), 1.4)
