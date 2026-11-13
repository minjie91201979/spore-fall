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
@export var behavior: String = "walk"     # walk / ambush / miasma / split / elite / boss
@export var tint: Color = Color(1, 1, 1, 1)   # 精灵染色（变种视觉区分）
@export var blood_color: Color = Color(0, 0, 0, 0)   # 死亡血渍颜色（a=0 = 未配置，回退 tint 调暗）
@export var scale_mult: float = 1.0            # 精灵缩放倍率（体型区分）
@export var sprite_texture: Texture2D          # 变种专属贴图（空 = 用场景默认）
@export var spawn_weight_tier0: float = 1.0    # 难度档 0 出现权重
@export var spawn_weight_per_tier: float = 0.0 # 每升一档增加的权重

# ---- 行为分支参数（§11.5 M4，配合 behavior 字段）----
# miasma：死亡原地留毒雾，按 dps 持续伤害，区域封锁逼玩家走位
@export var poison_radius: float = 78.0
@export var poison_duration: float = 4.0
@export var poison_dps: float = 10.0
# split：死亡裂出迷你子体（子体不再分裂，杜绝指数爆炸）
@export var split_count: int = 2
@export var split_hp_mult: float = 0.45
@export var split_size_mult: float = 0.62

# ---- 远程变种（§11.12 毒针 / 毒液喷射）----
# ranged_attack = "" 不远程；"needle" 单发毒针（快直线+命中挂毒）；
# "venom" 扇形毒液喷吐（慢毒团+落地/撞柱留毒云）。射程带内站桩前摇后开火，
# 太近（< ranged_min_range）收枪继续贴身追，给玩家「冲脸破解」的对策空间。
@export var ranged_attack: String = ""
@export var ranged_interval: float = 2.6    # 两轮射击间隔（秒）
@export var ranged_range: float = 380.0     # 开火最大距离
@export var ranged_min_range: float = 110.0 # 近于此距离不射击，转追击
@export var ranged_windup: float = 0.4      # 站桩前摇（可读的蓄射预警）
@export var ranged_damage_mult: float = 0.8 # 弹伤害 = attack_power × 该倍率
@export var ranged_poison_dps: float = 0.0  # 命中附加持续毒素（0 = 无毒）
@export var ranged_poison_time: float = 2.0
@export var spray_count: int = 1            # venom 扇形弹数
@export var spray_spread_deg: float = 34.0  # 扇形总张角
@export var leaves_cloud: bool = false      # 毒液落地/撞柱留毒云
@export var cloud_radius: float = 46.0
@export var cloud_duration: float = 2.6
@export var cloud_dps: float = 8.0

# ---- 精英 / Boss（§11.4.4 高潮点）----
@export var is_boss: bool = false          # true = 由计时事件召唤，不进随机选种池
@export var score_value: int = 10          # 击杀得分（Boss 远高于杂兵）
@export var contact_radius: float = 26.0   # 接触伤害判定半径（大体型 Boss 要放大）
@export var charge_interval: float = 3.4   # Boss 冲锋冷却（秒）
@export var charge_speed: float = 4.2      # 冲锋速度 = move_speed × 该倍率

# ---- Boss 技能组（§11.13，与冲锋独立冷却，非冲锋状态才可施放）----
# 三个技能循环随机（不连续重复同一个）：
#   0 孢子弹幕：360° 环形弹幕，封锁走位空间
#   1 剧毒喷息：朝玩家扇形毒液 + 落地毒云，正面区域封锁
#   2 巢群召唤：召 N 只 summon_stats 杂兵，围巢护主
@export var skill_interval: float = 5.5    # 技能冷却（秒）
@export var skill_range: float = 640.0     # 技能施放距离上限（贴太远不施法）
@export var radial_count: int = 14         # 弹幕环弹数
@export var breath_count: int = 7          # 喷息弹数
@export var breath_spread_deg: float = 44.0
@export var summon_count: int = 3
@export var summon_stats: EnemyStats       # 召唤杂兵用的参数谱（null 则跳过换弹幕）
