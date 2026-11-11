class_name DifficultyCurve
extends Resource
# 难度缩放工具（§11.4.4 / §6）：随难度档返回移速倍率与刷怪间隔。
# 纯静态方法，Spawning / Enemy 直接以 DifficultyCurve.xxx() 调用。

@export var speed_multiplier: float = 1.0

static func speed_for_tier(tier: int) -> float:
	return 1.0 + tier * 0.15

static func spawn_rate_for_tier(tier: int) -> float:
	return max(0.25, 1.2 - tier * 0.18)
