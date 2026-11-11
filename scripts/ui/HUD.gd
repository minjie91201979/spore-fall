extends Control
# 无尽模式 HUD（§11.6 / §7）：分数 / 连杀 / 存活时长 / 弹药 + 受击红屏脉冲。
@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var time_label: Label = $TimeLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var damage_flash: ColorRect = $DamageFlash

func _ready() -> void:
	EventBus.player_hit.connect(_on_player_hit)

func _on_player_hit(_dmg: int) -> void:
	# 受击红屏脉冲（§7）
	damage_flash.modulate.a = 0.5
	var t := create_tween()
	t.tween_property(damage_flash, "modulate:a", 0.0, 0.35)

func _process(_delta: float) -> void:
	if not GameState.is_running:
		return
	score_label.text = "SCORE %06d" % GameState.score
	combo_label.text = "COMBO x%d" % GameState.combo
	time_label.text = "%.1f" % GameState.survived_time
	var player = get_tree().get_first_node_in_group("player")
	if player and "ammo" in player:
		ammo_label.text = "AMMO %02d" % player.ammo
