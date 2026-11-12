extends Control
# 无尽模式 HUD（§11.6 / §7）：分数 / 连杀 / 存活时长 / 弹药 + 受击红屏脉冲。
@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var time_label: Label = $TimeLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var damage_flash: ColorRect = $DamageFlash

func _ready() -> void:
	EventBus.player_hit.connect(_on_player_hit)
	GameState.weapon_leveled.connect(_on_weapon_leveled)
	GameState.game_over.connect(_on_game_over)

func _on_game_over(_score: int, _time: float) -> void:
	# 死亡时让 HUD 淡出，给结算层让位
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.3, true, false, true).timeout
	hide()

func _on_player_hit(_dmg: int) -> void:
	# 受击红屏脉冲（§7）
	damage_flash.modulate.a = 0.5
	var t := create_tween()
	t.tween_property(damage_flash, "modulate:a", 0.0, 0.35)

func _on_weapon_leveled(_lv: int) -> void:
	# 升级金色脉冲
	weapon_label.modulate = Color(1.0, 0.85, 0.3)
	weapon_label.scale = Vector2(1.35, 1.35)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(weapon_label, "modulate", Color.WHITE, 0.6)
	t.tween_property(weapon_label, "scale", Vector2.ONE, 0.3)

func _process(_delta: float) -> void:
	if not GameState.is_running:
		return
	score_label.text = "SCORE %06d" % GameState.score
	combo_label.text = "COMBO x%d" % GameState.combo
	time_label.text = "%.1f" % GameState.survived_time
	var player = get_tree().get_first_node_in_group("player")
	if player and "ammo" in player:
		if player.get("infinite_ammo"):
			ammo_label.text = "AMMO ∞"
		else:
			ammo_label.text = "AMMO %02d" % player.ammo
	weapon_label.text = "WEAPON LV%d  %d/%d" % [
		GameState.weapon_level, GameState.crystals, GameState.crystals_for_next()]
