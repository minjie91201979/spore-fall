extends StaticBody2D
# 场上障碍柱：阻挡玩家/敌人移动与弹道。
# 放进 "obstacle" 组后，子弹撞上会销毁；Arena 重烘焙导航网格时按碰撞形状挖洞。
# 杂兵用 NavigationAgent2D 绕行，不再靠射线切向擦过去。

func _ready() -> void:
	add_to_group("obstacle")
