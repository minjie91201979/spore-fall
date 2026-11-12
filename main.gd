extends Node
# 全局游戏状态：无尽模式的计时 / 分数 / 难度档 / 连杀（§11.2 / §11.4）
# 同时负责在启动时用代码注册 InputMap 动作，避免 project.godot 手写序列化风险。

signal difficulty_changed(tier: int)
signal game_over(final_score: int, survived_time: float)
signal weapon_leveled(level: int)
signal upgrade_ready(choices: Array)
signal upgrade_applied(id: String)

var survived_time: float = 0.0
var score: int = 0
var kill_count: int = 0
var difficulty_tier: int = 0
var is_running: bool = false

var combo: int = 0
var combo_timer: float = 0.0
var max_combo: int = 0
var _career_tick: float = 0.0   # 存活类成就每秒检查一次，不必每帧

# 武器升级线：拾取孢子晶体累积，攒满触发一次「三选一升级卡」（§11.11）
var weapon_level: int = 1
var crystals: int = 0
var upgrades_taken: int = 0

# 局内 Build 加成：卡片只改这里，Player / Bullet / Pickup 各自读取重算，
# 谁都不必认识「卡片」这个概念。乘区默认 1.0、加区默认 0；每局 start_run 全量重置。
var mods: Dictionary = {}
var taken_upgrades: Dictionary = {}

# 升级点门槛：基础 6 颗，每拿一张 +2（6 / 8 / 10 / 12 …）。
# 原来是 3/4/5，太密，暂停选卡会一直打断爽刷；拉稀疏后一局约 4~7 次选择。
const UPGRADE_COST_BASE := 6
const UPGRADE_COST_STEP := 2

static func default_mods() -> Dictionary:
	return {
		"fire_rate": 1.0, "damage": 1.0, "projectiles": 0,
		"move_speed": 1.0, "max_health": 0.0, "magnet": 1.0,
		"pierce": 0, "bullet_speed": 1.0,
	}

# 精英/Boss 高潮点（§11.4.4）：同一时间只允许一只，存活期间暂停常规刷怪
var boss_active: bool = false
var bosses_spawned: int = 0

# 本地最高分（标题页展示 / 结算页判定新纪录）
# 可写路径：探针改成临时文件，避免污染玩家真实最高分存档
var save_path: String = "user://save.cfg"
var best_score: int = 0

# 难度抬档时间阈值（秒）—— 前 2 分宽松，之后每 2/4/8 分抬档（§11.4.4 / §6）
const TIER_THRESHOLDS: Array = [0.0, 120.0, 240.0, 480.0]

func _ready() -> void:
	_register_input()
	_load_best()
	# 标题页 / 探针也可能直接读 mods，不能只靠 Arena.start_run 初始化
	mods = default_mods()

# ---------- 输入注册（代码方式，等价于 project.godot [input]） ----------
func _register_input() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_up", KEY_UP)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_down", KEY_DOWN)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("attack", KEY_SPACE)
	_add_key_action("interact", KEY_E)

func _add_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var exists := false
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey and e.physical_keycode == keycode:
			exists = true
			break
	if exists:
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)

# ---------- 局状态 ----------
func start_run() -> void:
	survived_time = 0.0
	score = 0
	kill_count = 0
	combo = 0
	combo_timer = 0.0
	max_combo = 0
	difficulty_tier = 0
	weapon_level = 1
	crystals = 0
	upgrades_taken = 0
	mods = default_mods()
	taken_upgrades.clear()
	# 上一局若在选卡界面中退出（重载/返回标题），别把暂停状态带进新一局
	get_tree().paused = false
	boss_active = false
	bosses_spawned = 0
	is_running = true
	Career.reset_run()

func end_run() -> void:
	is_running = false
	boss_active = false
	# 破纪录先落盘，再广播：结算页据此判断要不要打「新纪录」
	if score > best_score:
		best_score = score
		_save_best()
	# 生涯统计与成就先结算，结算页才能读到本局新解锁
	Career.record_run(score, survived_time, kill_count, max_combo)
	game_over.emit(score, survived_time)

# ---------- 本地最高分 ----------
func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		best_score = int(cfg.get_value("record", "best_score", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)   # 保留其它字段，读不到就用空配置
	cfg.set_value("record", "best_score", best_score)
	cfg.save(save_path)

func register_kill(points: int = 10) -> void:
	kill_count += 1
	score += points
	combo += 1
	combo_timer = 2.5
	max_combo = maxi(max_combo, combo)
	Career.note_kill()

# ---------- 局内升级（三选一，§11.11） ----------
func crystals_for_next() -> int:
	# 用 weapon_level 而非「已选卡数」做门槛：攒满瞬间就抬价，
	# 不必等玩家点完卡片，也不会因为卡池抽空而卡在旧门槛
	return UPGRADE_COST_BASE + (weapon_level - 1) * UPGRADE_COST_STEP

func add_crystal() -> void:
	crystals += 1
	if crystals < crystals_for_next():
		return
	crystals = 0
	# 基础成长保留：即便卡池抽空，射速/伤害/弹道线依旧有节奏地往上走
	weapon_level += 1
	weapon_leveled.emit(weapon_level)
	var choices: Array = UpgradePool.pick(taken_upgrades)
	if not choices.is_empty():
		upgrade_ready.emit(choices)

# 应用一张卡：只累加 mods，并广播让 Player / HUD 刷新。
# 暂停与恢复由 UpgradeUI 负责，GameState 不持有任何 UI 状态。
func apply_upgrade(id: String) -> void:
	if UpgradePool.by_id(id).is_empty():
		return
	taken_upgrades[id] = int(taken_upgrades.get(id, 0)) + 1
	upgrades_taken += 1
	match id:
		"fire_rate":
			mods.fire_rate *= 1.15
		"damage":
			mods.damage *= 1.20
		"projectiles":
			mods.projectiles += 1
		"move_speed":
			mods.move_speed *= 1.12
		"vitality":
			mods.max_health += 25.0
		"magnet":
			mods.magnet *= 1.30
		"pierce":
			mods.pierce += 1
		"bullet_speed":
			mods.bullet_speed *= 1.25
	upgrade_applied.emit(id)

func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if not is_running:
		return
	survived_time += delta
	_career_tick += delta
	if _career_tick >= 1.0:
		_career_tick = 0.0
		Career.note_time(survived_time)
	var new_tier := _tier_for_time(survived_time)
	if new_tier != difficulty_tier:
		difficulty_tier = new_tier
		difficulty_changed.emit(difficulty_tier)

func _tier_for_time(t: float) -> int:
	var tier := 0
	for i in range(TIER_THRESHOLDS.size()):
		if t >= TIER_THRESHOLDS[i]:
			tier = i
	return tier
