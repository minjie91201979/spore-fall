extends Node2D
# 环外随机刷怪 + 难度缩放（§11.4.3 / §11.4.4）。
# 以主角为圆心、固定半径外的 ring 随机点生成（非固定波次）；
# 刷怪间隔随难度档缩短。切片阶段用 instantiate 方式（对象池作为后续性能优化，见 §11.9）。

@export var enemy_scene: PackedScene
@export var spawn_radius_min: float = 420.0
@export var spawn_radius_max: float = 620.0
# 变种参数谱（§11.5）：按难度档加权随机选种，改 .tres 即换怪
@export var variants: Array[EnemyStats] = []

var _spawn_timer: float = 0.0
var _player: Node2D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if not GameState.is_running or not _player or not enemy_scene:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _interval()
		_spawn_one()

func _interval() -> float:
	return DifficultyCurve.spawn_rate_for_tier(GameState.difficulty_tier)

func _spawn_one() -> void:
	# 对象池取敌人（§11.9），池缺失时退回 instantiate 兜底
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	var e: Node2D
	if pool:
		e = pool.acquire(get_tree().current_scene) as Node2D
	else:
		e = enemy_scene.instantiate()
		get_tree().current_scene.add_child(e)
	# 变种选种：按难度档权重随机（tier 越高，Runner/Brute 占比越高）
	var s := _pick_variant()
	if e.has_method("configure") and s:
		e.configure(s)
	var angle: float = randf() * TAU
	var r: float = randf_range(spawn_radius_min, spawn_radius_max)
	e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * r

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
