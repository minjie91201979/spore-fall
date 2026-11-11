extends Control
# 死亡结算界面（§11.4.6 / DoD「死亡即终局」）。
# 监听 GameState.game_over，显示最终分数与存活时长，提供「重新开始」。

@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var time_label: Label = $Panel/VBox/TimeLabel

func _ready() -> void:
	hide()
	GameState.game_over.connect(_on_game_over)

func _on_game_over(final_score: int, survived_time: float) -> void:
	score_label.text = "SCORE %06d" % final_score
	time_label.text = "存活 %.1f 秒" % survived_time
	show()

func _on_restart_pressed() -> void:
	# Arena._ready 会在重载后自动 start_run()
	get_tree().reload_current_scene()
