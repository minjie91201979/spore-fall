extends SceneTree

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 12:
		await process_frame
	var player = get_first_node_in_group("player")
	print("PLAYER_FOUND=", player != null)
	if player == null:
		quit()
		return
	player.take_damage(99999.0)
	print("AFTER_DAMAGE is_dead=", player.is_dead, " time_scale=", Engine.time_scale)
	await create_timer(1.5, true, false, true).timeout
	var ui = current_scene.get_node_or_null("UILayer/GameOver")
	var hud = current_scene.get_node_or_null("UILayer/HUD")
	print("GAMEOVER_VISIBLE=", ui.visible if ui else "MISSING")
	print("HUD_VISIBLE=", hud.visible if hud else "MISSING")
	print("TIME_SCALE_RESTORED=", Engine.time_scale)
	print("PLAYER_VISIBLE=", player.visible)
	quit()
