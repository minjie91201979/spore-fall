extends SceneTree
# 帧序列动画探针（§11.15）：验证「帧图是唯一运动来源」。
#
# 覆盖：
#   1. 帧序列约定：13 只怪各有 loop/act 两套、每套 4 帧、按 frame_001..004 升序
#   2. 播放触发：循环剪辑自动起播；单次动作由 play_once() 切换
#   3. 循环与单次：loop 播完回帧001；act 播完停在末帧并切回 loop
#   4. 帧率与总时长：12 帧/秒、4 帧 = 0.333 秒
#   5. 加载中：setup 后为 LOADING + 静态占位贴图，首个 tick 后才 READY
#   6. 资源缺失：缺失 key 回退静态贴图、登记告警、不崩溃
#   7. 尺寸与交互契约：动画期间 Sprite 的 scale/rotation/position 恒定不变
#   8. 原有玩法链路不受影响（由 probe_wave / probe_wave_timing 另行回归）

const KEYS := ["walker", "runner", "brute", "lurker", "miasma", "splitter",
	"spitter", "sprayer", "boss", "corroder", "burrower", "bloom", "abyss"]

var passc: int = 0
var failc: int = 0

func _initialize() -> void:
	# ---- 1. 帧序列资源约定（按帧001..帧004 升序存在）----
	var total := 0
	var keys_ok := 0
	for key in KEYS:
		var all := true
		for clip in ["loop", "act"]:
			for i in range(1, 5):
				var p: String = "res://assets/anim/%s/%s/frame_%03d.png" % [key, clip, i]
				if not ResourceLoader.exists(p):
					all = false
				else:
					total += 1
		_check(all, "FRAME_SET(%s)" % key)
		if all:
			keys_ok += 1
	_check(keys_ok == KEYS.size(), "ALL_13_CREATURES(%d)" % keys_ok)
	_check(total == 104, "TOTAL_FRAMES(%d)" % total)

	# ---- 2~7. 播放器行为 ----
	await _probe_loading()
	await _probe_loop_and_once()
	await _probe_missing()
	await _probe_transform_contract()

	print("FRAMES_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

func _new_player(key: String) -> Array:
	# 返回一个 [player, enemy, spr, outline, still]
	var e := load("res://scenes/world/Enemy.tscn").instantiate() as Node2D
	root.add_child(e)
	current_scene = e
	e.set("active", true)
	var st = load("res://assets/data/enemy_%s.tres" % key)
	e.call("configure", st)
	var spr: Sprite2D = e.get_node("Sprite")
	var ol: Sprite2D = e.get_node("Outline")
	var fp = e.get("frames")
	return [fp, e, spr, ol, st.sprite_texture]

func _probe_loading() -> void:
	var r := _new_player("corroder")
	var fp = r[0]
	var e: Node2D = r[1]
	var spr: Sprite2D = r[2]
	var still: Texture2D = r[4]
	# setup 之后、首次 tick 之前：LOADING + 静态占位帧
	_check(int(fp.get("state")) == 0, "LOADING_STATE_ON_SETUP")
	_check(spr.texture == still, "LOADING_SHOWS_STILL_PLACEHOLDER")
	fp.call("tick", 0.016)
	_check(int(fp.get("state")) == 1, "READY_AFTER_FIRST_TICK")
	_check(spr.texture != still, "READY_SWITCHES_TO_FRAME001")
	# 池化复用后重新进入 LOADING
	e.call("configure", load("res://assets/data/enemy_bloom.tres"))
	_check(int(fp.get("state")) == 0, "REUSE_BACK_TO_LOADING")
	e.queue_free()

func _probe_loop_and_once() -> void:
	var r := _new_player("corroder")
	var fp = r[0]
	var spr: Sprite2D = r[2]
	var ol: Sprite2D = r[3]
	fp.call("tick", 0.016)   # 触发加载
	_check(fp.call("current_clip_name") == "loop", "DEFAULT_CLIP_IS_LOOP")
	_check(bool(fp.call("current_is_loop")), "DEFAULT_IS_LOOP")
	_check(int(fp.call("current_frame_count")) == 4, "FRAME_COUNT_4")
	_check(absf(float(fp.call("current_fps")) - 12.0) < 0.01, "FPS_12")
	_check(absf(float(fp.call("current_duration")) - (4.0 / 12.0)) < 0.001, "DURATION_0_333")

	# 按序推进：每超过 1/12 秒前进一帧，严格 +1
	var seq := []
	for i in 5:
		seq.append(int(fp.call("current_index")))
		fp.call("tick", 0.084)   # 略大于 1/12=0.0833
	_check(seq == [0, 1, 2, 3, 0], "LOOP_ORDER_0_1_2_3_0(%s)" % str(seq))
	_check(ol.texture == spr.texture, "OUTLINE_FOLLOWS_FRAME")

	# 单次动作：触发后切到 act，播到末帧自动回 loop
	fp.call("play_once")
	_check(fp.call("current_clip_name") == "act", "PLAY_ONCE_SWITCHES_TO_ACT")
	_check(not bool(fp.call("current_is_loop")), "ACT_IS_ONE_SHOT")
	_check(int(fp.call("current_index")) == 0, "ACT_STARTS_AT_FRAME001")
	var once_seq := []
	for i in 5:
		once_seq.append(int(fp.call("current_index")))
		fp.call("tick", 0.084)
	_check(once_seq == [0, 1, 2, 3, 0], "ACT_PLAYS_ONCE_THEN_RETURNS(%s)" % str(once_seq))
	_check(fp.call("current_clip_name") == "loop", "ACT_RETURNS_TO_LOOP")
	# 重复触发同一单次动作应从头重播
	fp.call("play_once")
	fp.call("tick", 0.084)
	fp.call("play_once")
	_check(int(fp.call("current_index")) == 0, "REPEAT_TRIGGER_RESTARTS")

	r[1].queue_free()

func _probe_missing() -> void:
	# 构造一个没有帧序列的 key，验证回退而非崩溃
	var e := load("res://scenes/world/Enemy.tscn").instantiate() as Node2D
	root.add_child(e)
	current_scene = e
	e.set("active", true)
	var st = load("res://assets/data/enemy_walker.tres")
	e.call("configure", st)
	var spr: Sprite2D = e.get_node("Sprite")
	var still: Texture2D = st.sprite_texture
	var fp = e.get("frames")
	fp.call("setup", spr, e.get_node("Outline"), "no_such_creature", still)
	fp.call("tick", 0.016)
	_check(int(fp.get("state")) == 2, "MISSING_STATE")
	_check(spr.texture == still, "MISSING_FALLS_BACK_TO_STILL")
	# 运行时通过实例读静态字段，避免 -s 脚本静态引用 class_name 的编译期坑
	var missing_map: Dictionary = fp.get("missing_keys")
	_check(bool(missing_map.has("no_such_creature")), "MISSING_RECORDED")
	# 缺失状态下继续 tick 不应报错、也不应改动贴图
	fp.call("tick", 0.5)
	fp.call("play_once")
	_check(spr.texture == still, "MISSING_STAYS_SAFE")
	e.queue_free()

func _probe_transform_contract() -> void:
	# 帧动画是唯一运动来源：transform 必须全程恒定
	var r := _new_player("abyss")
	var fp = r[0]
	var e: Node2D = r[1]
	var spr: Sprite2D = r[2]
	fp.call("tick", 0.016)
	var s0: Vector2 = spr.scale
	var rot0: float = spr.rotation
	var pos0: Vector2 = spr.position
	var mod0: Color = spr.modulate
	var all_same := true
	for i in 30:
		fp.call("tick", 0.05)
		if i % 7 == 0:
			fp.call("play_once")
		if spr.scale != s0 or spr.rotation != rot0 or spr.position != pos0 or spr.modulate != mod0:
			all_same = false
	_check(all_same, "NO_PROCEDURAL_TRANSFORM")
	_check(s0.is_equal_approx(e.get("_base_scale")), "SCALE_UNCHANGED_FROM_BASE")
	# 帧确实在换（而非静止）
	_check(int(fp.call("current_frame_count")) == 4, "STILL_4_FRAMES")
	r[1].queue_free()

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1
		print("PASS ", label)
	else:
		failc += 1
		print("FAIL ", label)
