extends Node
# 移动端输入桥：虚拟摇杆写入 move_vector，玩家移动/攻击逻辑读取它。
# 桌面端无触摸时 move_vector 恒为 0，不干扰键盘输入。
var move_vector := Vector2.ZERO
# 自动瞄准开关已移到 Settings（系统设置，可持久化 + 游戏内切换），本文件只管输入。
