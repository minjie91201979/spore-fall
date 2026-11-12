class_name EnemyStats
extends Resource
# 敌人参数谱（数据驱动，§11.5）：五维 + 行为标签。
# 策划改表即换怪，不改代码。后续在编辑器里创建多个 .tres 资源即可区分游走体/伏击体/精英。

@export var display_name: String = "Walker"
@export var hearing: float = 300.0        # 听觉敏感度（被声音吸引半径）
@export var move_speed: float = 90.0
@export var max_health: float = 40.0
@export var attack_power: float = 8.0
@export var alert_radius: float = 320.0   # 进入即追
@export var behavior: String = "walk"     # walk / ambush / elite / boss
@export var tint: Color = Color(1, 1, 1, 1)   # 精灵染色（变种视觉区分）
@export var scale_mult: float = 1.0            # 精灵缩放倍率（体型区分）
@export var spawn_weight_tier0: float = 1.0    # 难度档 0 出现权重
@export var spawn_weight_per_tier: float = 0.0 # 每升一档增加的权重

# ---- 精英 / Boss（§11.4.4 高潮点）----
@export var is_boss: bool = false          # true = 由计时事件召唤，不进随机选种池
@export var score_value: int = 10          # 击杀得分（Boss 远高于杂兵）
@export var contact_radius: float = 26.0   # 接触伤害判定半径（大体型 Boss 要放大）
@export var charge_interval: float = 3.4   # Boss 冲锋冷却（秒）
@export var charge_speed: float = 4.2      # 冲锋速度 = move_speed × 该倍率
