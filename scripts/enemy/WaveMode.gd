extends Node2D
# 波次控制器（§新增）：取代 Spawner 的计时精英机制。
# 第一波 BOSS（母巢孢）被击溃后，弹出「进入下一波」提示卡（WaveCard），
# 玩家确认（或 5 秒自动）后进入第二波：持续刷出三只新型孢体，
# 并在延迟后召唤第二波 BOSS（渊噬孢 · Abyssal Devourer）。
#
# 数据流：复用 EnemyPool.acquire + Enemy.configure，与 Spawner.spawn_boss 同构；
# 通过 EventBus.boss_defeated 串联两波，GameState.boss_active 作为全局单 Boss 互斥锁。

const BROOD := preload("res://assets/data/enemy_boss.tres")
const CORRODER := preload("res://assets/data/enemy_corroder.tres")
const BURROWER := preload("res://assets/data/enemy_burrower.tres")
const BLOOM := preload("res://assets/data/enemy_bloom.tres")
const ABYSS := preload("res://assets/data/enemy_abyss.tres")

@export var wave2_delay: float = 25.0        # 第二波开始到召唤渊噬孢的延迟（秒）
@export var boss_spawn_radius: float = 520.0 # Boss 在玩家周围的登场距离

var _wave: int = 0
var _boss_down: bool = false
var _wave2_started: bool = false
var _wave2_t: float = 0.0
var _player: Node2D
var _card: CanvasLayer

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	EventBus.boss_defeated.connect(_on_boss_defeated)
	GameState.boss_active = false

func _process(delta: float) -> void:
	if not GameState.is_running:
		return
	if _wave == 0 and not _boss_down:
		_start_wave1()
		return
	if _wave2_started and not _boss_down:
		_wave2_t += delta
		if _wave2_t >= wave2_delay:
			_spawn_boss(ABYSS, 1.0)

func _start_wave1() -> void:
	_wave = 1
	GameState.objective_text = "目标　击溃母巢孢 · 第一波"
	_spawn_boss(BROOD, 1.0)

func _spawn_boss(stats: EnemyStats, hp_mult: float) -> void:
	if GameState.boss_active or not _player or not is_instance_valid(_player):
		return
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	var e: Node2D
	if pool:
		e = pool.acquire(get_tree().current_scene) as Node2D
	else:
		var scn := load("res://scenes/world/Enemy.tscn")
		e = scn.instantiate()
		get_tree().current_scene.add_child(e)
	if e == null or not e.has_method("configure"):
		return
	e.configure(stats, hp_mult)
	var angle: float = randf() * TAU
	e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * boss_spawn_radius
	GameState.boss_active = true
	GameState.bosses_spawned += 1
	EventBus.boss_spawned.emit(stats.display_name, e.get("max_health"))
	Juice.add_trauma(0.6)
	Juice.haptic(120)
	Sfx.play("hurt", 0.4, 5.0)

func _on_boss_defeated(_name: String) -> void:
	if _boss_down:
		return
	_boss_down = true
	if _wave == 1:
		_show_wave_card()
	elif _wave == 2:
		GameState.objective_text = "目标　区域已肃清"

func _show_wave_card() -> void:
	_card = get_tree().get_first_node_in_group("wave_card")
	if _card == null:
		_start_wave2()
		return
	get_tree().paused = true
	if _card.has_method("present"):
		_card.present("第二波 · WAVE 2", "深巢反扑", "DEEP NEST COUNTEROFFENSIVE")
	if not _card.is_connected("continued", _on_card_continued):
		_card.continued.connect(_on_card_continued)

func _on_card_continued() -> void:
	get_tree().paused = false
	_start_wave2()

func _start_wave2() -> void:
	_wave = 2
	_wave2_started = true
	_wave2_t = 0.0
	_boss_down = false   # 允许第二波 BOSS 再次触发 _on_boss_defeated
	GameState.objective_text = "目标　深巢反扑 · 第二波"
	# 把三只新怪注入 Spawner 随机池，之后常规刷怪会混出它们
	var spawner: Node = get_parent().get_node_or_null("Spawner")
	if spawner and spawner.has_method("add_variant"):
		spawner.add_variant(CORRODER)
		spawner.add_variant(BURROWER)
		spawner.add_variant(BLOOM)
	# 立刻来一波直接刷出的新怪，给玩家即时压力
	_spawn_immediate(CORRODER, 2)
	_spawn_immediate(BURROWER, 2)
	_spawn_immediate(BLOOM, 1)

func _spawn_immediate(stats: EnemyStats, n: int) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	if pool == null:
		return
	for i in n:
		var e: Node2D = pool.acquire(get_tree().current_scene) as Node2D
		if e == null or not e.has_method("configure"):
			continue
		e.configure(stats)
		var angle: float = randf() * TAU
		var r: float = randf_range(420.0, 620.0)
		e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * r
