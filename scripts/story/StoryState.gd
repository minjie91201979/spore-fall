extends Node
# 剧情存档。只写 user://story.cfg，不碰最高分和生涯。
# 运行时的「正在重玩 / 刚倒下」标记不进磁盘，避免把一次重开写成主线进度。

const SAVE_PATH_DEFAULT := "user://story.cfg"
const SAFEHOUSE_ID := "quarantine_3"
const PROLOGUE_SCENE := "res://scenes/story/Prologue.tscn"
const SAFEHOUSE_SCENE := "res://scenes/story/Safehouse.tscn"
const MISSION1_SCENE := "res://scenes/story/Mission01.tscn"
const MISSION2_SCENE := "res://scenes/story/Mission02.tscn"
const MISSION3_SCENE := "res://scenes/story/Mission03.tscn"
const MISSION4_SCENE := "res://scenes/story/Mission04.tscn"
const MISSION5_SCENE := "res://scenes/story/Mission05.tscn"
const SELECT_SCENE := "res://scenes/ui/StorySelect.tscn"
const TITLE_SCENE := "res://scenes/ui/Title.tscn"

var save_path: String = SAVE_PATH_DEFAULT

var has_save: bool = false
var prologue_complete: bool = false
var mission1_complete: bool = false
var mission2_complete: bool = false
var mission3_complete: bool = false
var mission4_complete: bool = false
var mission5_complete: bool = false
var pei_choice: String = ""   # "" / "A"(翠障剂) / "B"(焚毁)，M4 观察廊决定，M5 引用
var current_safehouse: String = SAFEHOUSE_ID
var ammo: int = 24
var health: float = 100.0
var crystals: int = 0
var herbs: int = 0
var current_weapon: String = "deagle"
var owned_weapons: Array = ["deagle"]
var files_read: Array[String] = []
var radio_contacted: bool = false
var met_amang: bool = false
var arrival_played: bool = false
var bought_ammo: bool = false
var bought_herb: bool = false
var cabinet_taken: bool = false
var station_pass: bool = false
var breaker_key: bool = false
var visitor_pass: bool = false
var descent_card: bool = false
var spore_clump: bool = false
var spore_sold: bool = false
var filter_core: bool = false
var filter_sold: bool = false
var han_home: bool = false
var argument_seen: bool = false
var m1_deaths: int = 0
var m2_deaths: int = 0
var m3_deaths: int = 0
var deaths: int = 0
var saved_unix: int = 0
var last_lu: int = -1
var last_mang: int = -1
var last_han: int = -1
var key_text: String = ""

# —— 不进磁盘 ——
var replaying: bool = false
var carry_loadout: bool = false
var departure_ammo: int = 24
var departure_health: float = 100.0
var departure_crystals: int = 0
var departure_herbs: int = 0
var pending_arrival: bool = false
var pending_death_line: bool = false
var pending_chapter: String = ""
var pending_death_mission: String = ""
var returned_live: bool = false
var briefing_done: bool = false
var active_mission: String = ""
var retry_contacted: bool = false
var chapter_kills: int = 0
var in_safehouse: bool = false

func _ready() -> void:
	load_disk()

func missions_cleared() -> int:
	# 通关统计不含序章。
	var n := 0
	if mission1_complete:
		n += 1
	if mission2_complete:
		n += 1
	if mission3_complete:
		n += 1
	if mission4_complete:
		n += 1
	if mission5_complete:
		n += 1
	return n

func recent_name() -> String:
	if mission5_complete:
		return "任务五　把根烧掉"
	if mission4_complete:
		return "任务四　向下生长"
	if mission3_complete:
		return "任务三　青潮的门"
	if mission2_complete:
		return "任务二　还在线上的人"
	if mission1_complete:
		return "任务一　所谓微量"
	return "序章　雨夜抵达"

func next_objective() -> String:
	if not prologue_complete:
		return StoryText.OBJECTIVE_PROLOGUE
	if not mission1_complete:
		return "目标　核查东堤培养观测站"
	if not mission2_complete:
		return "目标　前往市政巡查站"
	if not mission3_complete:
		return "目标　前往青潮生物外场仓库"
	if not mission4_complete:
		return "目标　下行至 B2 培养层，解救韩朔"
	if not mission5_complete:
		return "目标　深入翠巢主腔，焚毁本体"
	return ""

func chapter_unlocked(id: String) -> bool:
	match id:
		"prologue":
			return true
		"m1":
			return prologue_complete and has_save
		"m2":
			return mission1_complete
		"m3":
			return mission2_complete
		"m4":
			return mission3_complete
		"m5":
			return mission4_complete
		_:
			return false

func mission_done(id: String) -> bool:
	match id:
		"prologue":
			return prologue_complete
		"m1":
			return mission1_complete
		"m2":
			return mission2_complete
		"m3":
			return mission3_complete
		"m4":
			return mission4_complete
		"m5":
			return mission5_complete
		_:
			return false

func scene_for(id: String) -> String:
	match id:
		"m1":
			return MISSION1_SCENE
		"m2":
			return MISSION2_SCENE
		"m3":
			return MISSION3_SCENE
		"m4":
			return MISSION4_SCENE
		"m5":
			return MISSION5_SCENE
		"safehouse":
			return SAFEHOUSE_SCENE
		_:
			return PROLOGUE_SCENE

func save_stamp() -> String:
	if not has_save or saved_unix <= 0:
		return "尚未建立"
	return Time.get_datetime_string_from_unix_time(saved_unix, true).replace("T", " ")

func has_file(id: String) -> bool:
	return files_read.has(id)

func add_file(id: String) -> void:
	if not files_read.has(id):
		files_read.append(id)

func grant_key(which: String) -> void:
	match which:
		"station":
			station_pass = true
		"breaker":
			breaker_key = true
		"visitor":
			visitor_pass = true
		"descent":
			descent_card = true
		"clump":
			spore_clump = true
		"filter":
			filter_core = true
	refresh_keys()

func refresh_keys() -> void:
	var parts: PackedStringArray = []
	if station_pass:
		parts.append("观测站通行证")
	if breaker_key:
		parts.append("电闸钥匙")
	if visitor_pass:
		parts.append("访客证")
	if descent_card:
		parts.append("下行权限卡")
	if spore_clump and not spore_sold:
		parts.append("干结孢团")
	if filter_core and not filter_sold:
		parts.append("未开封滤芯")
	key_text = "　".join(parts)

func mark_mission(id: String) -> void:
	match id:
		"m1":
			mission1_complete = true
		"m2":
			mission2_complete = true
			han_home = true
		"m3":
			mission3_complete = true
			descent_card = true
		"m4":
			mission4_complete = true
		"m5":
			mission5_complete = true
	refresh_keys()

func load_disk() -> void:
	_read()
	_clear_runtime()

func _clear_runtime() -> void:
	replaying = false
	carry_loadout = false
	pending_arrival = false
	pending_death_line = false
	pending_chapter = ""
	pending_death_mission = ""
	returned_live = false
	briefing_done = false
	active_mission = ""
	retry_contacted = false
	in_safehouse = false

func clear_progress() -> void:
	var path := save_path
	_defaults()
	_clear_runtime()
	save_path = path
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func capture(player: Node) -> void:
	ammo = int(player.get("ammo"))
	health = float(player.get("health"))
	crystals = GameState.crystals
	current_weapon = GameState.current_weapon
	owned_weapons = GameState.owned_weapons.duplicate()

func apply_loadout() -> void:
	var owned: Array = owned_weapons.duplicate()
	if owned.is_empty():
		owned = ["deagle"]
	GameState.owned_weapons = owned.duplicate()
	GameState.current_weapon = current_weapon if owned.has(current_weapon) else "deagle"
	GameState.crystals = crystals
	GameState.weapon_level = 1
	GameState.mods = GameState.default_mods()
	GameState.upgrades_taken = 0
	GameState.taken_upgrades.clear()
	refresh_keys()

func write_save() -> void:
	has_save = true
	current_safehouse = SAFEHOUSE_ID
	saved_unix = int(Time.get_unix_time_from_system())
	var cfg := ConfigFile.new()
	cfg.set_value("story", "has_save", true)
	cfg.set_value("story", "prologue_complete", prologue_complete)
	cfg.set_value("story", "mission1_complete", mission1_complete)
	cfg.set_value("story", "mission2_complete", mission2_complete)
	cfg.set_value("story", "mission3_complete", mission3_complete)
	cfg.set_value("story", "mission4_complete", mission4_complete)
	cfg.set_value("story", "mission5_complete", mission5_complete)
	cfg.set_value("story", "pei_choice", pei_choice)
	cfg.set_value("story", "current_safehouse", current_safehouse)
	cfg.set_value("story", "ammo", ammo)
	cfg.set_value("story", "health", health)
	cfg.set_value("story", "crystals", crystals)
	cfg.set_value("story", "herbs", herbs)
	cfg.set_value("story", "current_weapon", current_weapon)
	cfg.set_value("story", "owned_weapons", ",".join(PackedStringArray(owned_weapons)))
	cfg.set_value("story", "files", ",".join(files_read))
	cfg.set_value("story", "radio_contacted", radio_contacted)
	cfg.set_value("story", "met_amang", met_amang)
	cfg.set_value("story", "arrival_played", arrival_played)
	cfg.set_value("story", "bought_ammo", bought_ammo)
	cfg.set_value("story", "bought_herb", bought_herb)
	cfg.set_value("story", "cabinet_taken", cabinet_taken)
	cfg.set_value("story", "station_pass", station_pass)
	cfg.set_value("story", "breaker_key", breaker_key)
	cfg.set_value("story", "visitor_pass", visitor_pass)
	cfg.set_value("story", "descent_card", descent_card)
	cfg.set_value("story", "spore_clump", spore_clump)
	cfg.set_value("story", "spore_sold", spore_sold)
	cfg.set_value("story", "filter_core", filter_core)
	cfg.set_value("story", "filter_sold", filter_sold)
	cfg.set_value("story", "han_home", han_home)
	cfg.set_value("story", "argument_seen", argument_seen)
	cfg.set_value("story", "m1_deaths", m1_deaths)
	cfg.set_value("story", "m2_deaths", m2_deaths)
	cfg.set_value("story", "m3_deaths", m3_deaths)
	cfg.set_value("story", "deaths", deaths)
	cfg.set_value("story", "saved_unix", saved_unix)
	cfg.set_value("story", "last_lu", last_lu)
	cfg.set_value("story", "last_mang", last_mang)
	cfg.set_value("story", "last_han", last_han)
	var err := cfg.save(save_path)
	if err != OK:
		push_error("剧情存档写入失败: %s" % save_path)

# 倒下后回安全屋。已有终端档就读它，不把这一趟没存的枪和文件写进去。
func return_from_death() -> void:
	var contacted_now := radio_contacted
	var mission := active_mission
	replaying = false
	carry_loadout = false
	pending_arrival = false
	if has_save:
		_read()
	else:
		_defaults()
		radio_contacted = contacted_now
		ammo = 24
		health = 100.0
		current_weapon = "deagle"
		owned_weapons = ["deagle"]
		deaths = 1
		has_save = true
		write_save()
	if has_save and mission != "":
		match mission:
			"m1":
				m1_deaths += 1
			"m2":
				m2_deaths += 1
			"m3":
				m3_deaths += 1
		deaths += 1
		write_save()
	pending_death_mission = mission
	pending_death_line = mission == "" and not prologue_complete
	retry_contacted = contacted_now
	active_mission = ""
	in_safehouse = true
	get_tree().change_scene_to_file(SAFEHOUSE_SCENE)

func _defaults() -> void:
	has_save = false
	prologue_complete = false
	mission1_complete = false
	mission2_complete = false
	mission3_complete = false
	mission4_complete = false
	mission5_complete = false
	pei_choice = ""
	current_safehouse = SAFEHOUSE_ID
	ammo = 24
	health = 100.0
	crystals = 0
	herbs = 0
	current_weapon = "deagle"
	owned_weapons = ["deagle"]
	files_read.clear()
	radio_contacted = false
	met_amang = false
	arrival_played = false
	bought_ammo = false
	bought_herb = false
	cabinet_taken = false
	station_pass = false
	breaker_key = false
	visitor_pass = false
	descent_card = false
	spore_clump = false
	spore_sold = false
	filter_core = false
	filter_sold = false
	han_home = false
	argument_seen = false
	m1_deaths = 0
	m2_deaths = 0
	m3_deaths = 0
	deaths = 0
	saved_unix = 0
	last_lu = -1
	last_mang = -1
	last_han = -1
	key_text = ""

func _read() -> void:
	_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	has_save = bool(cfg.get_value("story", "has_save", false))
	prologue_complete = bool(cfg.get_value("story", "prologue_complete", false))
	mission1_complete = bool(cfg.get_value("story", "mission1_complete", false))
	mission2_complete = bool(cfg.get_value("story", "mission2_complete", false))
	mission3_complete = bool(cfg.get_value("story", "mission3_complete", false))
	mission4_complete = bool(cfg.get_value("story", "mission4_complete", false))
	mission5_complete = bool(cfg.get_value("story", "mission5_complete", false))
	pei_choice = str(cfg.get_value("story", "pei_choice", ""))
	current_safehouse = str(cfg.get_value("story", "current_safehouse", SAFEHOUSE_ID))
	ammo = int(cfg.get_value("story", "ammo", 24))
	health = float(cfg.get_value("story", "health", 100.0))
	crystals = int(cfg.get_value("story", "crystals", 0))
	herbs = int(cfg.get_value("story", "herbs", 0))
	current_weapon = str(cfg.get_value("story", "current_weapon", "deagle"))
	owned_weapons.clear()
	for wid in str(cfg.get_value("story", "owned_weapons", "deagle")).split(",", false):
		owned_weapons.append(wid)
	if owned_weapons.is_empty():
		owned_weapons = ["deagle"]
	files_read.clear()
	for fid in str(cfg.get_value("story", "files", "")).split(",", false):
		files_read.append(fid)
	radio_contacted = bool(cfg.get_value("story", "radio_contacted", false))
	met_amang = bool(cfg.get_value("story", "met_amang", false))
	arrival_played = bool(cfg.get_value("story", "arrival_played", false))
	bought_ammo = bool(cfg.get_value("story", "bought_ammo", false))
	bought_herb = bool(cfg.get_value("story", "bought_herb", false))
	cabinet_taken = bool(cfg.get_value("story", "cabinet_taken", false))
	station_pass = bool(cfg.get_value("story", "station_pass", false))
	breaker_key = bool(cfg.get_value("story", "breaker_key", false))
	visitor_pass = bool(cfg.get_value("story", "visitor_pass", false))
	descent_card = bool(cfg.get_value("story", "descent_card", false))
	spore_clump = bool(cfg.get_value("story", "spore_clump", false))
	spore_sold = bool(cfg.get_value("story", "spore_sold", false))
	filter_core = bool(cfg.get_value("story", "filter_core", false))
	filter_sold = bool(cfg.get_value("story", "filter_sold", false))
	han_home = bool(cfg.get_value("story", "han_home", false))
	argument_seen = bool(cfg.get_value("story", "argument_seen", false))
	m1_deaths = int(cfg.get_value("story", "m1_deaths", 0))
	m2_deaths = int(cfg.get_value("story", "m2_deaths", 0))
	m3_deaths = int(cfg.get_value("story", "m3_deaths", 0))
	deaths = int(cfg.get_value("story", "deaths", 0))
	saved_unix = int(cfg.get_value("story", "saved_unix", 0))
	last_lu = int(cfg.get_value("story", "last_lu", -1))
	last_mang = int(cfg.get_value("story", "last_mang", -1))
	last_han = int(cfg.get_value("story", "last_han", -1))
	refresh_keys()
