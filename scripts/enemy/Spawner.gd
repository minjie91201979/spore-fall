extends Node2D
# 环外随机刷怪 + 难度缩放（§11.4.3 / §11.4.4）。
# 以主角为圆心、固定半径外的 ring 随机点生成（非固定波次）；
# 刷怪间隔随难度档缩短。切片阶段用 instantiate 方式（对象池作为后续性能优化，见 §11.9）。

@export var enemy_scene: PackedScene
@export var spawn_radius_min: float = 420.0
@export var spawn_radius_max: float = 620.0

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
	var e: Node2D = enemy_scene.instantiate()
	var angle: float = randf() * TAU
	var r: float = randf_range(spawn_radius_min, spawn_radius_max)
	e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * r
	get_tree().current_scene.add_child(e)
