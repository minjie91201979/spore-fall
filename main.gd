extends Node
# 全局游戏状态：无尽模式的计时 / 分数 / 难度档 / 连杀（§11.2 / §11.4）
# 同时负责在启动时用代码注册 InputMap 动作，避免 project.godot 手写序列化风险。

signal difficulty_changed(tier: int)
signal game_over(final_score: int, survived_time: float)
signal weapon_leveled(level: int)

var survived_time: float = 0.0
var score: int = 0
var kill_count: int = 0
var difficulty_tier: int = 0
var is_running: bool = false

var combo: int = 0
var combo_timer: float = 0.0
var max_combo: int = 0

# 武器升级线：拾取孢子晶体累积，攒满升级（射速/弹伤/弹道数成长）
var weapon_level: int = 1
var crystals: int = 0

# 精英/Boss 高潮点（§11.4.4）：同一时间只允许一只，存活期间暂停常规刷怪
var boss_active: bool = false
var bosses_spawned: int = 0

# 难度抬档时间阈值（秒）—— 前 2 分宽松，之后每 2/4/8 分抬档（§11.4.4 / §6）
const TIER_THRESHOLDS: Array = [0.0, 120.0, 240.0, 480.0]

func _ready() -> void:
	_register_input()

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
	boss_active = false
	bosses_spawned = 0
	is_running = true

func end_run() -> void:
	is_running = false
	boss_active = false
	game_over.emit(score, survived_time)

func register_kill(points: int = 10) -> void:
	kill_count += 1
	score += points
	combo += 1
	combo_timer = 2.5
	max_combo = maxi(max_combo, combo)

# ---------- 武器升级 ----------
# 升一级所需晶体数：lv1→3, lv2→4, lv3→5 ...（前期快、后期渐慢）
func crystals_for_next() -> int:
	return weapon_level + 2

func add_crystal() -> void:
	crystals += 1
	var leveled := false
	while crystals >= crystals_for_next():
		crystals -= crystals_for_next()
		weapon_level += 1
		leveled = true
	if leveled:
		weapon_leveled.emit(weapon_level)

func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if not is_running:
		return
	survived_time += delta
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
