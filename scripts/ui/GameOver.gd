extends Control
# 死亡结算界面（§11.4.6 / DoD「死亡即终局」）。
# 监听 GameState.game_over，等死亡演出播完后淡入，显示战绩并提供重开/退出。

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
	time_label.text = "存活时间  %d:%02d" % [mins, secs]
	kill_label.text = "击杀数  %d" % GameState.kill_count
	combo_label.text = "最高连杀  %d" % GameState.max_combo
	weapon_label.text = "武器等级  LV%d" % GameState.weapon_level
	# 等慢动作/淡出演出结束再弹结算；ignore_time_scale 保证计时真实
	await get_tree().create_timer(0.75, true, false, true).timeout
	if not is_inside_tree():
		return
	modulate.a = 0.0
	show()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

func _on_restart_pressed() -> void:
	# Arena._ready 重载后会重新 start_run()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
