extends Node2D
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 第3检疫所正压库。终端写 story.cfg。任务门从这里出发，死亡也回到这里。

const PICKUP: PackedScene = preload("res://scenes/world/Pickup.tscn")
const AMMO_PRICE := 1
const HERB_PRICE := 1

var _player: CharacterBody2D
var _session: StorySession
var _shop: CanvasLayer
var _shop_ammo: Button
var _shop_herb: Button
var _shop_clump: Button
var _shop_filter: Button
var _shop_crystals: Label
var _file_cursor: int = 0

func _ready() -> void:
	var replay := StoryState.replaying
	var arrival := StoryState.pending_arrival
	var chapter := StoryState.pending_chapter
	var death_mission := StoryState.pending_death_mission
	var death_line := StoryState.pending_death_line
	var contacted := StoryState.retry_contacted
	var kills := StoryState.chapter_kills
	var live := StoryState.returned_live
	if replay and not live:
		StoryState.load_disk()
	StoryState.returned_live = false
	StoryState.pending_chapter = ""
	StoryState.pending_death_mission = ""
	StoryState.pending_arrival = false
	StoryState.in_safehouse = true
	StoryState.active_mission = ""
	GameState.begin_story()
	StoryState.apply_loadout()
	_player = $Player
	_player.arena_clamp = false
	_player.infinite_ammo = false
	_player.position = Vector2(0, 40)
	_player.ammo = StoryState.ammo
	_player.health = clampf(StoryState.health, 1.0, _player.max_health)
	_player.control_mode = 0
	GameState.objective_text = StoryState.next_objective()
	_build()
	_session = StorySession.new()
	add_child(_session)
	_session.mount(_player)
	Sfx.start_bgm()
	Sfx.set_bgm_db(-18.0)
	Sfx.start_ambient("amb_hvac")
	if chapter != "":
		_play_chapter(chapter, kills, replay)
	elif arrival or (StoryState.prologue_complete and not StoryState.arrival_played and not replay):
		_play_arrival(kills)
	elif death_mission != "":
		_play_death(death_mission)
	elif death_line and not StoryState.prologue_complete:
		StoryState.pending_death_line = false
		var lines: Array = StoryText.retry_contacted() if contacted else StoryText.retry_silent()
		_session.say(lines)
	elif replay and chapter == "":
		_session.show_chapter("序 章 完 成", "序章　雨夜抵达", StoryText.CHAPTER_RESULT, kills, func() -> void:
			GameState.objective_text = StoryState.next_objective()
		)

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
			GameState.objective_text = StoryState.next_objective()
		)
	)

func _play_chapter(chapter: String, kills: int, replay: bool) -> void:
	var lines: Array = []
	var title := ""
	var result := ""
	match chapter:
		"m1":
			lines = StoryCopy.m1_return()
			title = StoryCopy.CHAPTER_M1
			result = StoryCopy.RESULT_M1
		"m2":
			lines = StoryCopy.m2_return()
			title = StoryCopy.CHAPTER_M2
			result = StoryCopy.RESULT_M2
		"m3":
			lines = StoryCopy.m3_return()
			title = StoryCopy.CHAPTER_M3
			result = StoryCopy.RESULT_M3
		"m4":
			lines = StoryCopy.m4_return()
			title = StoryCopy.CHAPTER_M4
			result = StoryCopy.RESULT_M4
		"m5":
			lines = StoryCopy.m5_return()
			title = StoryCopy.CHAPTER_M5
			result = StoryCopy.RESULT_M5
		_:
			return
	_player.control_mode = 2
	_session.say(lines, false, func() -> void:
		if chapter == "m2" and not replay:
			StoryState.argument_seen = true
			StoryState.capture(_player)
			StoryState.write_save()
		_session.show_chapter("任 务 完 成", title, result, kills, func() -> void:
			GameState.objective_text = StoryState.next_objective()
		)
	)

func _play_death(mission: String) -> void:
	var lines: Array = []
	match mission:
		"m1":
			lines = StoryCopy.m1_death_repeat() if StoryState.m1_deaths >= 3 else StoryCopy.m1_death()
		"m2":
			lines = StoryCopy.m2_death_saved() if StoryState.han_home else StoryCopy.m2_death()
		"m3":
			lines = StoryCopy.m3_death()
		_:
			return
	_session.say(lines)

func _on_terminal() -> void:
	StoryState.capture(_player)
	StoryState.write_save()
	_session._toast(StoryText.SAVE_DONE)
	_session.say([StoryText.line("值班终端", StoryText.SAVE_DONE)])

func _on_speaker() -> void:
	if not StoryState.prologue_complete:
		_session.say(StoryText.road_again())
		return
	var pool := _lu_pool()
	var idx := _next_index(pool, StoryState.last_lu)
	StoryState.last_lu = idx
	_session.say([StoryText.line("路晚棠（扬声器）", pool[idx], true)])

func _on_amang() -> void:
	if not StoryState.met_amang:
		StoryState.met_amang = true
		_session.say(StoryText.amang_meet())
		return
	var pool := _mang_pool()
	var idx := _next_index(pool, StoryState.last_mang)
	StoryState.last_mang = idx
	_session.say([StoryText.line("阿芒", pool[idx])])

func _on_han() -> void:
	if not StoryState.han_home:
		return
	var pool := _han_pool()
	var idx := _next_index(pool, StoryState.last_han)
	StoryState.last_han = idx
	_session.say([StoryText.line("韩朔", pool[idx])])

func _on_files() -> void:
	if StoryState.files_read.is_empty():
		return
	var id := StoryState.files_read[_file_cursor % StoryState.files_read.size()]
	_file_cursor += 1
	var spec: Dictionary = StoryCopy.file_spec(id)
	if str(spec.title) == "":
		return
	_session.open_file(str(spec.title), str(spec.body), spec.marks)

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
	StoryState.pending_chapter = ""
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

func _on_mission(id: String) -> void:
	if not StoryState.chapter_unlocked(id):
		return
	if id == "m3":
		var lines: Array = StoryCopy.m3_gate_lines(StoryState.argument_seen)
		_session.say(lines, false, func() -> void:
			StoryState.argument_seen = true
			_depart(id)
		)
		return
	if id == "m1":
		StoryState.briefing_done = true
		_session.say(StoryCopy.m1_depart(), false, func() -> void: _depart(id))
		return
	if id == "m2":
		StoryState.briefing_done = true
		_session.say(StoryCopy.m2_depart(), false, func() -> void: _depart(id))
		return
	if id == "m4":
		StoryState.briefing_done = true
		_session.say(StoryCopy.m4_depart(), false, func() -> void: _depart(id))
		return
	if id == "m5":
		StoryState.briefing_done = true
		_session.say(StoryCopy.m5_depart(), false, func() -> void: _depart(id))
		return
	_depart(id)

func _depart(id: String) -> void:
	if not StoryState.chapter_unlocked(id):
		return
	StoryState.replaying = StoryState.mission_done(id)
	StoryState.briefing_done = true
	StoryState.active_mission = id
	StoryState.capture(_player)
	StoryState.carry_loadout = true
	StoryState.pending_chapter = ""
	StoryState.pending_arrival = false
	StoryState.pending_death_line = false
	StoryState.pending_death_mission = ""
	StoryState.returned_live = false
	get_tree().change_scene_to_file(StoryState.scene_for(id))

func _on_shop() -> void:
	_refresh_shop()
	_shop.visible = true

func _refresh_shop() -> void:
	_shop_crystals.text = "晶体　%d" % GameState.crystals
	_shop_ammo.disabled = StoryState.bought_ammo or GameState.crystals < AMMO_PRICE
	_shop_ammo.text = "弹药 +12　·　已换" if StoryState.bought_ammo else "弹药 +12　·　%d 晶体" % AMMO_PRICE
	_shop_herb.disabled = StoryState.bought_herb or GameState.crystals < HERB_PRICE
	_shop_herb.text = "草药　·　已换" if StoryState.bought_herb else "草药　·　%d 晶体" % HERB_PRICE
	_shop_clump.visible = StoryState.spore_clump and not StoryState.spore_sold
	_shop_filter.visible = StoryState.filter_core and not StoryState.filter_sold

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

func _sell_clump() -> void:
	if not StoryState.spore_clump or StoryState.spore_sold:
		return
	StoryState.spore_clump = false
	StoryState.spore_sold = true
	_player.ammo += 16
	EventBus.pickup_collected.emit("ammo", 16)
	StoryState.refresh_keys()
	_refresh_shop()

func _sell_filter() -> void:
	if not StoryState.filter_core or StoryState.filter_sold:
		return
	StoryState.filter_core = false
	StoryState.filter_sold = true
	_player.ammo += 24
	EventBus.pickup_collected.emit("ammo", 24)
	StoryState.refresh_keys()
	_refresh_shop()

func _lu_pool() -> Array:
	if StoryState.mission2_complete:
		return StoryCopy.LU_M3
	if StoryState.mission1_complete:
		return StoryCopy.LU_M2
	return StoryText.LU_IDLE

func _mang_pool() -> Array:
	if StoryState.mission1_complete:
		return StoryCopy.MANG_M2
	return StoryText.MANG_IDLE

func _han_pool() -> Array:
	if StoryState.mission3_complete or StoryState.visitor_pass or StoryState.descent_card:
		return StoryCopy.HAN_M3
	return StoryCopy.HAN_BEFORE

func _next_index(pool: Array, last: int) -> int:
	if pool.size() <= 1:
		return 0
	var idx := randi() % pool.size()
	if idx == last:
		idx = (idx + 1) % pool.size()
	return idx

func _prompt_for(id: String) -> String:
	for chapter in StoryText.CHAPTERS:
		if str(chapter.id) != id:
			continue
		if StoryState.chapter_unlocked(id):
			var title := str(chapter.title)
			if StoryState.mission_done(id):
				title += "　已完成"
			return title
		return str(chapter.locked)
	return "？？？"

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
	if StoryState.han_home:
		var han := Sprite2D.new()
		han.texture = load("res://assets/characters/player.png")
		han.scale = Vector2(0.2, 0.2)
		han.modulate = Color(0.95, 0.55, 0.2)
		han.position = Vector2(-70, 50)
		add_child(han)
		var han_it := StoryWorld.interactable(self, Vector2(-70, 50), StoryText.PROMPT_NEAR)
		han_it.interacted.connect(_on_han)
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
	var east := StoryWorld.interactable(self, Vector2(250, 30), _prompt_for("m1"))
	east.interacted.connect(func() -> void: _on_mission("m1"))
	var north := StoryWorld.interactable(self, Vector2(200, -150), _prompt_for("m2"))
	north.interacted.connect(func() -> void: _on_mission("m2"))
	var west := StoryWorld.interactable(self, Vector2(-250, 90), _prompt_for("m3"))
	west.interacted.connect(func() -> void: _on_mission("m3"))
	var south_w := StoryWorld.interactable(self, Vector2(40, -160), _prompt_for("m4"))
	south_w.interacted.connect(func() -> void: _on_mission("m4"))
	var south_e := StoryWorld.interactable(self, Vector2(120, -150), _prompt_for("m5"))
	south_e.interacted.connect(func() -> void: _on_mission("m5"))
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
	box.offset_top = -180.0
	box.offset_bottom = 200.0
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
	_shop_clump = MenuChrome.ghost_button("干结孢团　换弹药 +16")
	_shop_clump.pressed.connect(_sell_clump)
	box.add_child(_shop_clump)
	_shop_filter = MenuChrome.ghost_button("未开封滤芯　换弹药 +24")
	_shop_filter.pressed.connect(_sell_filter)
	box.add_child(_shop_filter)
	var close := MenuChrome.ghost_button("关 闭")
	close.pressed.connect(func() -> void: _shop.visible = false)
	box.add_child(close)
	_refresh_shop()
