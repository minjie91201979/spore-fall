extends Node
# 剧情存档。只写 user://story.cfg，不碰最高分和生涯。
# 运行时的「正在重玩 / 刚倒下」标记不进磁盘，避免把一次重开写成主线进度。

const SAVE_PATH_DEFAULT := "user://story.cfg"
const SAFEHOUSE_ID := "quarantine_3"
const PROLOGUE_SCENE := "res://scenes/story/Prologue.tscn"
const SAFEHOUSE_SCENE := "res://scenes/story/Safehouse.tscn"
const SELECT_SCENE := "res://scenes/ui/StorySelect.tscn"
const TITLE_SCENE := "res://scenes/ui/Title.tscn"

var save_path: String = SAVE_PATH_DEFAULT

var has_save: bool = false
var prologue_complete: bool = false
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
var deaths: int = 0
var saved_unix: int = 0
var last_lu: int = -1
var last_mang: int = -1

# —— 不进磁盘 ——
var replaying: bool = false
var carry_loadout: bool = false
var departure_ammo: int = 24
var departure_health: float = 100.0
var departure_crystals: int = 0
var departure_herbs: int = 0
var pending_arrival: bool = false
var pending_death_line: bool = false
var retry_contacted: bool = false
var chapter_kills: int = 0
var in_safehouse: bool = false

func _ready() -> void:
	load_disk()

func missions_cleared() -> int:
	# 通关统计不含序章。任务一至五不在这一期。
	return 0

func recent_name() -> String:
	return "序章　雨夜抵达"

func save_stamp() -> String:
	if not has_save or saved_unix <= 0:
		return "尚未建立"
	return Time.get_datetime_string_from_unix_time(saved_unix, true).replace("T", " ")

func has_file(id: String) -> bool:
	return files_read.has(id)

func add_file(id: String) -> void:
	if not files_read.has(id):
		files_read.append(id)

func load_disk() -> void:
	_read()
	_clear_runtime()

func _clear_runtime() -> void:
	replaying = false
	carry_loadout = false
	pending_arrival = false
	pending_death_line = false
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
	herbs = herbs
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

func write_save() -> void:
	has_save = true
	current_safehouse = SAFEHOUSE_ID
	saved_unix = int(Time.get_unix_time_from_system())
	var cfg := ConfigFile.new()
	cfg.set_value("story", "has_save", true)
	cfg.set_value("story", "prologue_complete", prologue_complete)
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
	cfg.set_value("story", "deaths", deaths)
	cfg.set_value("story", "saved_unix", saved_unix)
	cfg.set_value("story", "last_lu", last_lu)
	cfg.set_value("story", "last_mang", last_mang)
	var err := cfg.save(save_path)
	if err != OK:
		push_error("剧情存档写入失败: %s" % save_path)

# 倒下后回安全屋。已有终端档就读它，不把这一趟的消耗写进去。
func return_from_death() -> void:
	var contacted_now := radio_contacted
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
	pending_death_line = not prologue_complete
	retry_contacted = contacted_now
	in_safehouse = true
	get_tree().change_scene_to_file(SAFEHOUSE_SCENE)

func _defaults() -> void:
	has_save = false
	prologue_complete = false
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
	deaths = 0
	saved_unix = 0
	last_lu = -1
	last_mang = -1

func _read() -> void:
	_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	has_save = bool(cfg.get_value("story", "has_save", false))
	prologue_complete = bool(cfg.get_value("story", "prologue_complete", false))
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
	deaths = int(cfg.get_value("story", "deaths", 0))
	saved_unix = int(cfg.get_value("story", "saved_unix", 0))
	last_lu = int(cfg.get_value("story", "last_lu", -1))
	last_mang = int(cfg.get_value("story", "last_mang", -1))
