extends Node
# 移动端输入桥：虚拟摇杆写入 move_vector，玩家移动/攻击逻辑读取它。
# 桌面端无触摸时 move_vector 恒为 0，不干扰键盘输入。
var move_vector := Vector2.ZERO
# 自动瞄准开关（手感参数）：摇杆/键盘只负责走位，开火自动锁最近敌人。
# 关掉即回到「最后移动方向 = 射击方向」的老手感（改这一行即可全局切换）。
var auto_aim: bool = true
