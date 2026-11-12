extends SceneTree
# 探针：画质档位（§11.6）。
# 断言三档下 描边可见性 / 手电光强与半径 / 粒子数量比例 真的变化，
# 且新建实体（池化后）能继承当前档位。

var quality: Node
var gs: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 15:
		await process_frame
	quality = get_root().get_node_or_null("Quality")
	gs = get_root().get_node_or_null("GameState")
	print("QUALITY_FOUND=", quality != null)
	if quality == null:
		quit()
		return
	gs.start_run()

	var player = get_first_node_in_group("player")
	var outline: Sprite2D = player.get_node("Outline")
	var flash: PointLight2D = player.get_node("Flashlight")

	quality.set_level(2)
	await process_frame
	print("HIGH outline=", outline.visible, " light=", flash.energy, " radius=", snappedf(flash.scale.x, 0.1),
		" particles=", _particle_ratio())

	quality.set_level(1)
	await process_frame
	print("MED  outline=", outline.visible, " light=", flash.energy, " radius=", snappedf(flash.scale.x, 0.1),
		" particles=", _particle_ratio())

	quality.set_level(0)
	await process_frame
	print("LOW  outline=", outline.visible, " light=", flash.energy, " radius=", snappedf(flash.scale.x, 0.1),
		" particles=", _particle_ratio())

	# 档位对「新生成实体」是否生效（池化复用路径）
	var spawner = current_scene.get_node_or_null("Spawner")
	var boss = spawner.spawn_boss()
	await process_frame
	if boss:
		print("NEW_BOSS_OUTLINE=", boss.get_node("Outline").visible)
		print("NEW_BOSS_PARTICLES=", boss.get_node("KillParticles").get("amount_ratio"))
		boss.take_damage(999999.0)

	print("CFG_SAVED=", FileAccess.file_exists("user://settings.cfg"))

	# 还原高档，别把测试用的低档留给下一次启动
	quality.set_level(2)
	print("RESTORED=", quality.level)
	print("OK")
	quit()

func _particle_ratio() -> String:
	var p = get_first_node_in_group("kill_particles")
	if p == null:
		return "NONE"
	return str(p.get("amount_ratio"))
