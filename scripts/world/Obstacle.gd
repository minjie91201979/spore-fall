extends StaticBody2D
# 场上障碍柱：阻挡玩家/敌人移动与弹道。
# 敌人无导航网格，靠 Enemy._steer_around_obstacles 的射线检测 + 切向绕行通过。
# 加入 "obstacle" 组供射线/子弹识别。

func _ready() -> void:
	add_to_group("obstacle")
