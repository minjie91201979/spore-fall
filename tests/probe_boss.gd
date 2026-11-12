extends SceneTree
# 探针：精英/Boss 高潮点（§11.4.4）端到端断言。
# 覆盖 召唤 → 血条显示/跟血 → Boss 战暂停刷怪 → 击杀结算与收尾。
# 注：--script 入口脚本在 Autoload 注册前编译，不能直接写 GameState，
#     须运行时 get_root().get_node() 取单例（场景内脚本不受影响）。

var gs: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 15:
		await process_frame
	gs = get_root().get_node_or_null("GameState")
	print("GAMESTATE_FOUND=", gs != null)
	if gs == null:
		quit()
		return
	gs.start_run()

	var spawner = current_scene.get_node_or_null("Spawner")
	var bar = current_scene.get_node_or_null("UILayer/BossBar")
	print("SPAWNER_FOUND=", spawner != null)
	print("BAR_FOUND=", bar != null)
	print("BAR_VISIBLE_BEFORE=", bar.visible if bar else "MISSING")
	if spawner == null or bar == null:
		quit()
		return

	var boss = spawner.spawn_boss()
	print("BOSS_NULL=", boss == null)
	if boss == null:
		quit()
		return
	print("IS_BOSS=", boss.is_boss)
	print("BOSS_MAX_HP=", boss.max_health)
	print("BOSS_IN_GROUP=", boss.is_in_group("boss"))
	print("BOSS_ACTIVE_FLAG=", gs.boss_active)
	print("BOSSES_SPAWNED=", gs.bosses_spawned)

	await create_timer(0.6, true, false, true).timeout
	print("BAR_VISIBLE_AFTER=", bar.visible)
	print("BAR_ALPHA=", snappedf(bar.modulate.a, 0.01))
	print("BAR_NAME=", bar.get_node("Box/NameLabel").text)
	print("BAR_FILL_FULL=", snappedf(bar.get_node("Box/Bar/BarFill").size.x, 0.1))

	# 掉 60% 血 → 血条跟读
	boss.take_damage(boss.max_health * 0.6)
	await process_frame
	print("BAR_FILL_AFTER_60=", snappedf(bar.get_node("Box/Bar/BarFill").size.x, 0.1))
	print("BAR_HP_TEXT=", bar.get_node("Box/HpText").text)

	# Boss 战期间常规刷怪应暂停（只数存活敌人，池里停车的 active=false 不计）
	var before := _count_active_enemies()
	await create_timer(2.0, true, false, true).timeout
	var after := _count_active_enemies()
	print("ACTIVE_ENEMIES_BEFORE=", before, " AFTER=", after)
	print("SPAWN_PAUSED=", after <= before)

	# 击杀 → 结算与血条收尾
	var score_before: int = gs.score
	boss.take_damage(boss.max_health)
	await create_timer(0.4, true, false, true).timeout
	print("BOSS_ACTIVE_AFTER_KILL=", gs.boss_active)
	print("SCORE_GAIN=", gs.score - score_before)
	print("KILL_COUNT=", gs.kill_count)
	print("BAR_TAG_AFTER=", bar.get_node("Box/TagLabel").text)
	print("PICKUPS=", _count_pickups())

	# 计时触发：把存活时间推到 8 分档，应自动召唤第二只且血量按成长系数抬升
	gs.survived_time = 481.0
	await create_timer(0.25, true, false, true).timeout
	print("BOSSES_AFTER_TIMER=", gs.bosses_spawned)
	var boss2 = get_first_node_in_group("boss")
	print("BOSS2_FOUND=", boss2 != null)
	if boss2:
		print("BOSS2_MAX_HP=", boss2.max_health)
		print("HP_GROWTH_APPLIED=", boss2.max_health > 3000.0)
	print("OK")
	quit()

func _count_active_enemies() -> int:
	var n := 0
	for e in get_nodes_in_group("enemy"):
		if e.get("active"):
			n += 1
	return n

func _count_pickups() -> int:
	return get_nodes_in_group("pickup").size()
