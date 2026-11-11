extends Camera2D
# 挂在 Camera2D 上：跟随玩家 + 读取 Juice.trauma 做屏幕震动（§11.4.5）。
# 跟随用 global_position 对齐玩家；屏震用 offset/rotation 叠加，两者不冲突。

@export var max_offset: float = 12.0
@export var max_roll: float = 0.05
@export var follow_smoothing: float = 0.15

func _process(_delta: float) -> void:
	# 相机跟随玩家（PC/移动端通用，避免角色跑出屏幕）
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		global_position = global_position.lerp(player.global_position, follow_smoothing)

	# 命中/击杀 trauma 平方后映射到位移与旋转
	var shake := Juice.trauma * Juice.trauma
	offset = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0) * max_offset * shake
	rotation = (randf() * 2.0 - 1.0) * max_roll * shake
