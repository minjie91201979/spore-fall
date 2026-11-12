extends SceneTree
# 性能压测（§11.7）：关垂直同步 → 固定同屏敌人数 → 三档画质各跑一段，记录帧时间分布。
# 用法（必须带窗口，headless 测不到 GPU）：
#   Godot_console.exe --path . --script tests/stress_test.gd
# 指标：fps_avg / avg 帧耗时 / p95 / 最差单帧 / draw calls 峰值。

const COUNTS := [100, 200]
const TIERS := [2, 1, 0]
const DURATION := 6.0

var gs: Node
var quality: Node
var player: Node2D
var pool: Node

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	for i in 20:
		await process_frame
	gs = get_root().get_node_or_null("GameState")
	quality = get_root().get_node_or_null("Quality")
	player = get_first_node_in_group("player")
	pool = get_first_node_in_group("enemy_pool")
	if gs == null or quality == null or player == null:
		print("SETUP_FAILED")
		quit()
		return

	gs.start_run()
	player.max_health = 1000000.0
	player.health = 1000000.0
	# 固定数量对照：关掉刷怪器与随机性来源
	current_scene.get_node("Spawner").set_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	print("GPU=", RenderingServer.get_video_adapter_name())
	print("VSYNC=off MAX_FPS=0")

	# 预热对象池：先灌满再清空，后面各轮都是纯复用，不与扩容开销混在一起
	_spawn_wave(200)
	for i in 20:
		await process_frame
	_clear_enemies()
	await create_timer(0.3, true, false, true).timeout

	for n in COUNTS:
		for t in TIERS:
			quality.set_level(t)
			_clear_enemies()
			_spawn_wave(n)
			await create_timer(0.6, true, false, true).timeout   # 让敌人先聚拢，进入稳定负载
			var r: Dictionary = await _measure()
			print("STRESS enemies=%d tier=%d fps_avg=%.1f med_ms=%.2f p95_ms=%.2f draws=%d" % [
				n, t, r["fps"], r["med"], r["p95"], r["draws"]])

	_clear_enemies()
	quality.set_level(2)   # 还原高档，别把测试档留给下次启动
	print("OK")
	quit()

func _measure() -> Dictionary:
	var times: Array[float] = []
	var draws := 0
	var elapsed := 0.0
	var last := Time.get_ticks_usec()
	while elapsed < DURATION:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000.0
		last = now
		if dt <= 0.0:
			continue
		times.append(dt)
		elapsed += dt / 1000.0
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort()
	var n: int = times.size()
	if n == 0:
		return {"fps": 0.0, "med": 0.0, "p95": 0.0, "draws": draws}
	var total := 0.0
	for v in times:
		total += v
	var avg_ms: float = total / float(n)
	return {
		"fps": 1000.0 / avg_ms,
		"med": times[n / 2],
		"p95": times[mini(int(float(n) * 0.95), n - 1)],
		"draws": draws,
	}

func _spawn_wave(count: int) -> void:
	var stats = load("res://assets/data/enemy_walker.tres")
	var scene: PackedScene = load("res://scenes/world/Enemy.tscn")
	for i in count:
		var e: Node2D
		if pool:
			e = pool.acquire(current_scene) as Node2D
		else:
			e = scene.instantiate()
			current_scene.add_child(e)
		if e.has_method("configure"):
			e.configure(stats)
		var a: float = TAU * float(i) / float(count)
		var r: float = 290.0 + float(i % 6) * 34.0
		e.global_position = player.global_position + Vector2(cos(a), sin(a)) * r

func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemy"):
		if not e.get("active"):
			continue
		e.set("active", false)
		if pool:
			pool.release(e)
		else:
			e.queue_free()
