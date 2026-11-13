extends Node2D
# 第3检疫所正压库。终端写 story.cfg，阿芒换一盒弹和一块草药，扬声器是路晚棠。

const PICKUP: PackedScene = preload("res://scenes/world/Pickup.tscn")
const AMMO_PRICE := 1
const HERB_PRICE := 1

var _player: CharacterBody2D
var _session: StorySession
var _shop: CanvasLayer
var _shop_ammo: Button
var _shop_herb: Button
var _shop_crystals: Label

func _ready() -> void:
	var replay := StoryState.replaying
	var arrival := StoryState.pending_arrival
	var death_line := StoryState.pending_death_line
	var contacted := StoryState.retry_contacted
	var kills := StoryState.chapter_kills
	if replay and not arrival:
		StoryState.load_disk()
	StoryState.in_safehouse = true
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(0, 40)
	_player.ammo = StoryState.ammo
	_player.health = clampf(StoryState.health, 1.0, _player.max_health)
	_player.control_mode = 0
	GameState.objective_text = "" if StoryState.prologue_complete else StoryText.OBJECTIVE_PROLOGUE
	_build()
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-18.0)
	if arrival or (StoryState.prologue_complete and not StoryState.arrival_played and not replay):
		_play_arrival(kills)
	elif replay:
		_session.show_chapter("序 章 完 成", "序章　雨夜抵达", StoryText.CHAPTER_RESULT, kills, func() -> void:
			GameState.objective_text = ""
		)
	elif death_line and not StoryState.prologue_complete:
		StoryState.pending_death_line = false
		var lines: Array = StoryText.retry_contacted() if contacted else StoryText.retry_silent()
		_session.say(lines)

func _process(_delta: float) -> void:
	if _session == null or not _session.gameplay_unlocked:
		return
	if StoryState.met_amang or _session.dialogue.active:
		return
	if _player.global_position.distance_to(Vector2(150, 70)) < 90.0:
		StoryState.met_amang = true
		_session.say(StoryText.amang_meet())

func _play_arrival(kills: int) -> void:
	StoryState.pending_arrival = false
	StoryState.prologue_complete = true
	StoryState.write_save()
	GameState.objective_text = ""
	var lines: Array = StoryText.arrival()
	if not StoryState.met_amang:
		lines.append_array(StoryText.amang_meet())
		StoryState.met_amang = true
	_player.control_mode = 2
	_session.say(lines, false, func() -> void:
		StoryState.arrival_played = true
		StoryState.capture(_player)
		StoryState.prologue_complete = true
		StoryState.write_save()
		_session.show_chapter("序 章 完 成", "序章　雨夜抵达", StoryText.CHAPTER_RESULT, kills, func() -> void:
			GameState.objective_text = ""
		)
	)

func _on_terminal() -> void:
	StoryState.capture(_player)
	StoryState.write_save()
	_session._toast(StoryText.SAVE_DONE)
	_session.say([StoryText.line("值班终端", StoryText.SAVE_DONE)])

func _on_speaker() -> void:
	if not StoryState.prologue_complete:
		_session.say(StoryText.road_again())
		return
	var idx := _next_index(StoryText.LU_IDLE, StoryState.last_lu)
	StoryState.last_lu = idx
	_session.say([StoryText.line("路晚棠（扬声器）", StoryText.LU_IDLE[idx], true)])

func _on_amang() -> void:
	if not StoryState.met_amang:
		StoryState.met_amang = true
		_session.say(StoryText.amang_meet())
		return
	var idx := _next_index(StoryText.MANG_IDLE, StoryState.last_mang)
	StoryState.last_mang = idx
	_session.say([StoryText.line("阿芒", StoryText.MANG_IDLE[idx])])

func _on_files() -> void:
	if not StoryState.has_file("gate_log"):
		return
	_session.open_file("《关卡值班记录》", StoryText.GATE_LOG)

func _on_cabinet() -> void:
	if StoryState.cabinet_taken:
		return
	StoryState.cabinet_taken = true
	_player.ammo += 16
	EventBus.pickup_collected.emit("ammo", 16)

func _on_door() -> void:
	# 南门回到序章。通关后重玩不覆盖主存档；没通关则带上屋里的弹药。
	StoryState.pending_arrival = false
	StoryState.pending_death_line = false
	if StoryState.prologue_complete:
		StoryState.replaying = true
		StoryState.carry_loadout = false
	else:
		StoryState.replaying = false
		StoryState.carry_loadout = true
		StoryState.departure_ammo = _player.ammo
		StoryState.departure_health = _player.health
		StoryState.departure_crystals = GameState.crystals
		StoryState.departure_herbs = StoryState.herbs
	get_tree().change_scene_to_file(StoryState.PROLOGUE_SCENE)

func _on_shop() -> void:
	_refresh_shop()
	_shop.visible = true

func _refresh_shop() -> void:
	_shop_crystals.text = "晶体　%d" % GameState.crystals
	_shop_ammo.disabled = StoryState.bought_ammo or GameState.crystals < AMMO_PRICE
	_shop_ammo.text = "弹药 +12　·　已换" if StoryState.bought_ammo else "弹药 +12　·　%d 晶体" % AMMO_PRICE
	_shop_herb.disabled = StoryState.bought_herb or GameState.crystals < HERB_PRICE
	_shop_herb.text = "草药　·　已换" if StoryState.bought_herb else "草药　·　%d 晶体" % HERB_PRICE

func _buy_ammo() -> void:
	if StoryState.bought_ammo or GameState.crystals < AMMO_PRICE:
		return
	GameState.crystals -= AMMO_PRICE
	StoryState.crystals = GameState.crystals
	StoryState.bought_ammo = true
	_player.ammo += 12
	EventBus.pickup_collected.emit("ammo", 12)
	_refresh_shop()

func _buy_herb() -> void:
	if StoryState.bought_herb or GameState.crystals < HERB_PRICE:
		return
	GameState.crystals -= HERB_PRICE
	StoryState.crystals = GameState.crystals
	StoryState.bought_herb = true
	StoryState.herbs += 1
	_session._toast("草药")
	_refresh_shop()

func _next_index(pool: Array, last: int) -> int:
	if pool.size() <= 1:
		return 0
	var idx := randi() % pool.size()
	if idx == last:
		idx = (idx + 1) % pool.size()
	return idx

func _build() -> void:
	StoryWorld.add_ground(self, Vector2.ZERO, 1, Color(0.5, 0.56, 0.6))
	var blocks: Array[Dictionary] = []
	for spec in [
		[Vector2(0, -210), Vector2(640, 28)],
		[Vector2(0, 210), Vector2(640, 28)],
		[Vector2(-310, 0), Vector2(28, 420)],
		[Vector2(310, 0), Vector2(28, 420)],
	]:
		StoryWorld.add_wall(self, spec[0], spec[1], Color(0.12, 0.16, 0.2))
		blocks.append({"center": spec[0], "size": spec[1]})
	StoryWorld.add_patch(self, Vector2(160, 110), Vector2(120, 50), Color(0.28, 0.2, 0.12))
	StoryWorld.add_patch(self, Vector2(-40, -70), Vector2(70, 36), Color(0.2, 0.24, 0.28))
	StoryWorld.add_light(self, Vector2(0, -150), Color(0.3, 0.95, 0.9), 2.4)
	var mang := Sprite2D.new()
	mang.texture = load("res://assets/characters/player.png")
	mang.scale = Vector2(0.2, 0.2)
	mang.modulate = Color(0.92, 0.74, 0.45)
	mang.position = Vector2(150, 70)
	add_child(mang)
	var speaker := StoryWorld.add_patch(self, Vector2(-180, -160), Vector2(46, 18), Color(0.2, 0.55, 0.52))
	speaker.z_index = 1
	var terminal := StoryWorld.interactable(self, Vector2(-180, -50), StoryText.PROMPT_TERMINAL)
	terminal.interacted.connect(_on_terminal)
	var radio := StoryWorld.interactable(self, Vector2(-180, -150), StoryText.PROMPT_NEAR)
	radio.interacted.connect(_on_speaker)
	var amang := StoryWorld.interactable(self, Vector2(150, 70), StoryText.PROMPT_NEAR)
	amang.radius = 70.0
	amang.interacted.connect(_on_amang)
	var stall := StoryWorld.interactable(self, Vector2(200, 130), StoryText.PROMPT_NEAR)
	stall.interacted.connect(_on_shop)
	var files := StoryWorld.interactable(self, Vector2(-20, -140), StoryText.PROMPT_NEAR)
	files.interacted.connect(_on_files)
	if not StoryState.cabinet_taken:
		var cabinet := StoryWorld.interactable(self, Vector2(-40, -40), StoryText.PROMPT_NEAR)
		cabinet.interacted.connect(_on_cabinet)
	var door := StoryWorld.interactable(self, Vector2(0, 160), "序章　雨夜抵达")
	door.interacted.connect(_on_door)
	var locked := StoryWorld.interactable(self, Vector2(220, -40), "任 务 一　？？？")
	locked.radius = 50.0
	var heal: Node2D = PICKUP.instantiate()
	heal.kind = "heal"
	heal.persistent = true
	heal.position = Vector2(90, -90)
	add_child(heal)
	_shop = CanvasLayer.new()
	_shop.layer = 35
	_shop.visible = false
	add_child(_shop)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	_shop.add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -200.0
	box.offset_right = 200.0
	box.offset_top = -140.0
	box.offset_bottom = 150.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_shop.add_child(box)
	box.add_child(MenuChrome.label("阿芒", 22, Color(0.9, 0.78, 0.5)))
	_shop_crystals = MenuChrome.label("晶体　0", 14, Color(0.7, 0.85, 0.82))
	box.add_child(_shop_crystals)
	_shop_ammo = MenuChrome.primary_button("弹药 +12")
	_shop_ammo.pressed.connect(_buy_ammo)
	box.add_child(_shop_ammo)
	_shop_herb = MenuChrome.ghost_button("草药")
	_shop_herb.pressed.connect(_buy_herb)
	box.add_child(_shop_herb)
	var close := MenuChrome.ghost_button("关 闭")
	close.pressed.connect(func() -> void: _shop.visible = false)
	box.add_child(close)
