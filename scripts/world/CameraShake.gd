extends Camera2D
# 挂在 Camera2D 上：跟随玩家 + 读取 Juice.trauma 做屏幕震动（§11.4.5）。
# 跟随用 global_position 对齐玩家；屏震用 offset/rotation 叠加，两者不冲突。

@export var max_offset: float = 12.0
@export var max_roll: float = 0.05
@export var follow_smoothing: float = 0.15
# 过场把镜头钉在场景上，而不是立刻跟玩家。生存局保持 false。
var hold_follow: bool = false
var hold_target: Vector2 = Vector2.ZERO

# 相机可视半宽/半高（按 1152x648 设计分辨率），用于把镜头夹在场地内
const CAM_LIMIT := Vector2(324.0, 576.0)

func _process(_delta: float) -> void:
	# 相机跟随玩家（PC/移动端通用，避免角色跑出屏幕）
	if hold_follow:
		global_position = global_position.lerp(hold_target, follow_smoothing)
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			global_position = global_position.lerp(player.global_position, follow_smoothing)
	# 夹在竞技场内，避免露出地面外的灰色 clear color
	global_position.x = clampf(global_position.x, -CAM_LIMIT.x, CAM_LIMIT.x)
	global_position.y = clampf(global_position.y, -CAM_LIMIT.y, CAM_LIMIT.y)

	# 命中/击杀 trauma 平方后映射到位移与旋转
	var shake := Juice.trauma * Juice.trauma
	offset = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0) * max_offset * shake
	rotation = (randf() * 2.0 - 1.0) * max_roll * shake
