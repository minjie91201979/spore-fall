extends SceneTree
# 验证：生涯统计 + 成就（实时解锁 / 结算累计 / 持久化 / 去重 / UI 接线）。
# 用临时存档路径，绝不污染玩家真实 user://career.cfg。

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 25:
		await process_frame
	var c = get_root().get_node_or_null("Career")
	var gs = get_root().get_node_or_null("GameState")
	var bus = get_root().get_node_or_null("EventBus")
	var fired: Array[String] = []
	bus.achievement_unlocked.connect(func(n): fired.append(n))

	# ---------- 隔离存档 + 状态归零 ----------
	c.save_path = "user://career_probe.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path))
	c.total_runs = 0
	c.total_kills = 0
	c.total_playtime = 0.0
	c.best_survival = 0.0
	c.best_combo = 0
	c.best_kills = 0
	c.unlocked.clear()
	c.reset_run()
	c._load()
	var init_ok: bool = c.unlocked_count() == 0 and c.total_runs == 0
	print("INIT ok=%s" % init_ok)

	# ---------- 累计击杀实时解锁 ----------
	for i in 99:
		c.note_kill()
	var before_100: bool = not c.unlocked.has("kills_100")
	c.note_kill()
	var kill_ach: bool = before_100 and c.unlocked.has("kills_100") \
		and c.run_new.has("百孢斩") and fired.has("百孢斩")
	print("KILL_ACH ok=%s fired=%d" % [kill_ach, fired.size()])

	# ---------- 存活时长成就 ----------
	c.note_time(299.0)
	var no_early: bool = not c.unlocked.has("survive_300")
	c.note_time(300.5)
	var time_ach: bool = no_early and c.unlocked.has("survive_300")
	print("TIME_ACH ok=%s" % time_ach)

	# ---------- 结算累计 + 单局成就 ----------
	c.record_run(5200, 310.0, 42, 26)
	var run_ok: bool = c.total_runs == 1 and is_equal_approx(c.total_playtime, 310.0) \
		and is_equal_approx(c.best_survival, 310.0) and c.best_combo == 26 and c.best_kills == 42 \
		and c.unlocked.has("first_run") and c.unlocked.has("score_5000") \
		and c.unlocked.has("combo_25")
	print("RUN_RECORD ok=%s unlocked=%d" % [run_ok, c.unlocked_count()])

	# ---------- 解锁去重 ----------
	var fired_before: int = fired.size()
	c.record_run(100, 20.0, 3, 2)
	var no_dup: bool = fired.size() == fired_before and c.total_runs == 2 \
		and is_equal_approx(c.best_survival, 310.0)
	print("NO_DUP ok=%s runs=%d" % [no_dup, c.total_runs])

	# ---------- 持久化读回 ----------
	var script = load("res://scripts/systems/CareerStats.gd")
	var c2 = script.new()
	c2.save_path = c.save_path
	c2._load()
	var persist_ok: bool = c2.total_runs == 2 and c2.total_kills == 100 \
		and c2.unlocked_count() == c.unlocked_count() \
		and is_equal_approx(c2.best_survival, 310.0)
	c2.free()
	print("PERSIST ok=%s" % persist_ok)

	# ---------- 展示文案 ----------
	var text_ok: bool = c.summary().contains("2 局") and c.summary().contains("5:10") \
		and c.title_line().contains("成就 %d/%d" % [c.unlocked_count(), 6]) and c.achievement_line().contains("新成就")
	print("TEXT ok=%s | %s" % [text_ok, c.summary()])

	# ---------- UI 节点接线 ----------
	var go = load("res://scenes/ui/GameOver.tscn").instantiate()
	var title = load("res://scenes/ui/Title.tscn").instantiate()
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	var ui_ok: bool = go.get_node_or_null("Panel/VBox/CareerLabel") != null \
		and go.get_node_or_null("Panel/VBox/AchievementLabel") != null \
		and title.get_node_or_null("Center/CareerLabel") != null \
		and hud.get_node_or_null("ToastLabel") != null
	go.free(); title.free(); hud.free()
	print("UI_WIRED ok=%s" % ui_ok)

	# ---------- GameState 接线：register_kill / end_run ----------
	gs.save_path = "user://save_probe.cfg"   # 隔离 end_run 的 best_score 写盘
	gs.start_run()
	var kills_before: int = c.total_kills
	gs.register_kill(10)
	var gs_kill_ok: bool = c.total_kills == kills_before + 1
	var runs_before: int = c.total_runs
	gs.score = 123
	gs.survived_time = 12.0
	gs.kill_count = 3
	gs.max_combo = 2
	gs.end_run()
	var gs_end_ok: bool = c.total_runs == runs_before + 1
	print("GAMESTATE_WIRE kill=%s end=%s" % [gs_kill_ok, gs_end_ok])

	# 还原存档路径，避免影响同进程后续逻辑
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	c.save_path = "user://career.cfg"
	gs.save_path = "user://save.cfg"

	var all_ok: bool = init_ok and kill_ach and time_ach and run_ok and no_dup \
		and persist_ok and text_ok and ui_ok and gs_kill_ok and gs_end_ok
	print("PROBE_RESULT=", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
