extends Area2D
# 子弹（§11.4.3 远程）：直线飞行，命中敌人调用 take_damage，命中或超时销毁。
@export var speed: float = 620.0
@export var damage: float = 12.0
@export var lifetime: float = 1.2

var _direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = _direction.angle()

# 由 Player 在生成时设定飞行方向
func setup(direction: Vector2) -> void:
	_direction = direction.normalized()

func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(damage)
		queue_free()
