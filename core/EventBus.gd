extends Node
# 解耦事件总线（§11.2）：击杀 / 受击 / 拾取广播，避免节点间硬引用。

signal enemy_killed(position: Vector2, points: int)
signal player_hit(damage: int)
signal pickup_collected(type: String, amount: int)
