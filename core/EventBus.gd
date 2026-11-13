extends Node
# 解耦事件总线（§11.2）：击杀 / 受击 / 拾取广播，避免节点间硬引用。

signal enemy_killed(position: Vector2, points: int)
signal player_hit(damage: int)
signal pickup_collected(type: String, amount: int)
# 有限弹药空仓：HUD 闪红。生存模式弹药无限，不会发出。
signal weapon_dry_fired

# 精英/Boss 高潮点（§11.4.4）：刷怪器召唤 → HUD 血条跟读 → 死亡收尾
signal boss_spawned(display_name: String, max_health: float)
signal boss_damaged(health: float, max_health: float)
signal boss_defeated(display_name: String)

# 画质档位切换（§11.6）：HUD 按钮文案等 UI 跟随刷新
signal quality_changed(level: int)

# 生涯成就解锁（§11.8）：局内实时广播，HUD 用 toast 提示
signal achievement_unlocked(display_name: String)
