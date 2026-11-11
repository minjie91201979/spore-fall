extends Control
# 死亡结算界面（§11.4.6 / DoD「死亡即终局」）。
# 监听 GameState.game_over，显示分数 / 存活时长 / 击杀数 / 最高连杀 / 武器等级，
# 提供「重新开始」。

@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var kill_label: Label = $Panel/VBox/KillLabel
@onready var combo_label: Label = $Panel/VBox/ComboLabel
@onready var weapon_label: Label = $Panel/VBox/WeaponLabel

func _ready() -> void:
	hide()
	GameState.game_over.connect(_on_game_over)

func _on_game_over(final_score: int, survived_time: float) -> void:
	score_label.text = "SCORE %06d" % final_score
	var mins := floori(survived_time / 60.0)
	var secs := int(survived_time) % 60
	time_label.text = "存活 %d:%02d" % [mins, secs]
	kill_label.text = "击杀 %d" % GameState.kill_count
	combo_label.text = "最高连杀 %d" % GameState.max_combo
	weapon_label.text = "武器 LV%d" % GameState.weapon_level
	show()

func _on_restart_pressed() -> void:
	# Arena._ready 会在重载后自动 start_run()
	get_tree().reload_current_scene()
