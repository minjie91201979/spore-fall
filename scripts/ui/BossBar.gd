extends Control
# 精英/Boss 血条（§11.4.4）：顶部居中，仅在 Boss 存活期间显示。
# 数据全走 EventBus，不与被召唤的敌人实例硬引用（池化复用下实例可能换手）。

const BAR_W := 510.0

@onready var tag_label: Label = $Box/TagLabel
@onready var name_label: Label = $Box/NameLabel
@onready var hp_text: Label = $Box/HpText
@onready var bar_fill: ColorRect = $Box/Bar/BarFill

var _bar_tween: Tween

func _ready() -> void:
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_damaged.connect(_on_boss_damaged)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	GameState.game_over.connect(_on_game_over)
	visible = false
	modulate.a = 0.0

# 玩家死亡：血条立即让位给结算面板
func _on_game_over(_score: int, _time: float) -> void:
	visible = false

func _on_boss_spawned(boss_name: String, max_hp: float) -> void:
	tag_label.text = "精 英 个 体 · ELITE"
	name_label.text = boss_name
	name_label.modulate = Color.WHITE
	hp_text.text = "%d / %d" % [int(max_hp), int(max_hp)]
	_set_fill(0.0)
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.28)
	# 血条从左侧充能拉满：登场即有的「压迫感建立」动作
	_animate_fill(BAR_W, 0.5)

func _on_boss_damaged(hp: float, max_hp: float) -> void:
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()   # 玩家开打即接管血条，避免与登场充能抢同一属性
	_set_fill(hp / maxf(max_hp, 1.0))
	hp_text.text = "%d / %d" % [maxi(int(hp), 0), int(max_hp)]

func _on_boss_defeated(_boss_name: String) -> void:
	tag_label.text = "目 标 已 清 除"
	hp_text.text = "TARGET DOWN"
	_animate_fill(0.0, 0.35)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(name_label, "modulate", Color(1.0, 0.86, 0.36, 1.0), 0.2)
	tw.tween_interval(0.9)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(hide)

func _set_fill(ratio: float) -> void:
	bar_fill.size.x = BAR_W * clampf(ratio, 0.0, 1.0)

func _animate_fill(target: float, dur: float) -> void:
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.set_ignore_time_scale(true)
	_bar_tween.tween_property(bar_fill, "size:x", target, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
