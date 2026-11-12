extends Node2D
# 环外随机刷怪 + 难度缩放（§11.4.3 / §11.4.4）。
# 以主角为圆心、固定半径外的 ring 随机点生成（非固定波次）；
# 刷怪间隔随难度档缩短。切片阶段用 instantiate 方式（对象池作为后续性能优化，见 §11.9）。

@export var enemy_scene: PackedScene
@export var spawn_radius_min: float = 420.0
@export var spawn_radius_max: float = 620.0
# 变种参数谱（§11.5）：按难度档加权随机选种，改 .tres 即换怪
@export var variants: Array[EnemyStats] = []

# 精英/Boss 高潮点（§11.4.4）：3 / 8 / 15 分各召唤一只，切片阶段共用同一套占位 Boss。
@export var boss_stats: EnemyStats
@export var elite_times: Array[float] = [180.0, 480.0, 900.0]
# 每多召唤一轮，血量按该系数递增（抵消玩家武器成长，避免后期秒杀）
@export var boss_hp_growth: float = 1.4
# 同屏存活上限（§11.9）：玩家一直跑不打时也不让敌人无限堆积，保住帧率底线
@export var max_alive: int = 150

var _spawn_timer: float = 0.0
var _elite_index: int = 0
var _player: Node2D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if not GameState.is_running or not _player or not enemy_scene:
		return
	_check_elite_events()
	# Boss 战期间暂停常规刷怪：把「被淹没的混战」切成一场可读的单挑
	if GameState.boss_active:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _interval()
		_spawn_one()

func _check_elite_events() -> void:
	while _elite_index < elite_times.size() and GameState.survived_time >= elite_times[_elite_index]:
		_elite_index += 1
		spawn_boss()

# 召唤精英（公开 API，测试探针也直接调用）。返回实例，失败返回 null。
func spawn_boss() -> Node2D:
	if not boss_stats or GameState.boss_active or not _player:
		return null
	var e: Node2D = _acquire_enemy()
	if e == null:
		return null
	var hp_mult: float = 1.0 + boss_hp_growth * float(GameState.bosses_spawned)
	if e.has_method("configure"):
		e.configure(boss_stats, hp_mult)
	var angle: float = randf() * TAU
	e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius_max
	GameState.boss_active = true
	GameState.bosses_spawned += 1
	EventBus.boss_spawned.emit(boss_stats.display_name, e.get("max_health"))
	# 登场仪式感：屏幕一震 + 低频吼 + 场上杂兵被冲击波清开（不做，留白给 Boss 让位）
	Juice.add_trauma(0.6)
	Sfx.play("hurt", 0.4, 5.0)
	return e

func _acquire_enemy() -> Node2D:
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	if pool:
		return pool.acquire(get_tree().current_scene) as Node2D
	if not enemy_scene:
		return null
	var e: Node2D = enemy_scene.instantiate()
	get_tree().current_scene.add_child(e)
	return e

func _interval() -> float:
	return DifficultyCurve.spawn_rate_for_tier(GameState.difficulty_tier)

func _spawn_one() -> void:
	# 封顶：只数存活中的（池里停车的不算），到上限就跳过本次刷怪
	if _alive_count() >= max_alive:
		return
	var e: Node2D = _acquire_enemy()
	if e == null:
		return
	# 变种选种：按难度档权重随机（tier 越高，Runner/Brute 占比越高）
	var s := _pick_variant()
	if e.has_method("configure") and s:
		e.configure(s)
	var angle: float = randf() * TAU
	var r: float = randf_range(spawn_radius_min, spawn_radius_max)
	e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * r

func _alive_count() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active"):
			n += 1
	return n

func _pick_variant() -> EnemyStats:
	if variants.is_empty():
		return null
	var tier := GameState.difficulty_tier
	var weights: Array[float] = []
	var total := 0.0
	for s in variants:
		var w: float = s.spawn_weight_tier0 + s.spawn_weight_per_tier * tier
		weights.append(max(w, 0.0))
		total += max(w, 0.0)
	if total <= 0.0:
		return variants[0]
	var roll := randf() * total
	for i in variants.size():
		roll -= weights[i]
		if roll <= 0.0:
			return variants[i]
	return variants[variants.size() - 1]
