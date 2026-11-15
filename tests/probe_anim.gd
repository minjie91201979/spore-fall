extends SceneTree
# 动画层探针（§11.14）：证明 13 种怪的动作真的在跑、风格有差异、事件脉冲生效、
# 池化复用无残留。不只看"变量存在"，而是采样 Sprite 的 transform 时间序列。
#
# 注意：--script 入口在 autoload 注册前编译，单例须运行时 get_root().get_node() 取。

var passc: int = 0
var failc: int = 0

const STYLES := {
	"walker": "WALK", "runner": "RUN", "brute": "ELITE", "lurker": "AMBUSH",
	"miasma": "FLOAT", "splitter": "SPLIT", "spitter": "WALK", "sprayer": "WALK",
	"corroder": "WALK", "burrower": "AMBUSH", "bloom": "FLOAT",
	"boss": "BOSS", "abyss": "BOSS",
}

func _initialize() -> void:
	# 逐一实例化并 configure，驱动一段时间，采样 transform
	var results := {}
	for key in STYLES:
		var path: String = "res://assets/data/enemy_%s.tres" % (key as String)
		var st = load(path)
		if st == null:
			_fail("TRES(%s)" % key)
			continue
		var e := _make_enemy(st)
		if e == null:
			_fail("SPAWN(%s)" % key)
			continue
		var samples := await _sample(e, 26)
		var base: float = float(e.get("_base_scale").x)
		var amp := _amplitude(samples, base)
		results[key] = amp
		_check(amp > 0.0005, "ANIMATES(%s amp=%.4f)" % [key, amp])
		# 描边层必须与本体同步（否则低画质之外会出现描边脱节）
		var spr: Sprite2D = e.get_node("Sprite")
		var ol: Sprite2D = e.get_node("Outline")
		_check(ol.scale.is_equal_approx(spr.scale), "OUTLINE_SYNC(%s)" % key)
		# 风格映射断言
		_check(int(e.get("anim").get("_style")) == _style_id(STYLES[key]), "STYLE(%s=%s)" % [key, STYLES[key]])
		e.queue_free()

	# ---- 风格差异：不同 style 的动作幅度/相位不该完全一样 ----
	_check(absf(float(results.get("runner", 0.0)) - float(results.get("boss", 0.0))) > 0.0002,
		"STYLE_DIFFERS(runner vs boss)")

	# ---- 事件脉冲 ----
	await _probe_pulses()

	# ---- 池化复用：换怪后相位与变换必须归零 ----
	await _probe_reuse()

	print("ANIM_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

func _make_enemy(st) -> Node2D:
	var e := load("res://scenes/world/Enemy.tscn").instantiate() as Node2D
	root.add_child(e)
	current_scene = e
	e.set("active", true)
	e.call("configure", st)
	return e

func _sample(e: Node2D, n: int) -> Array:
	var out := []
	var spr: Sprite2D = e.get_node("Sprite")
	for i in n:
		await process_frame
		out.append(spr.scale.x)
	return out

func _amplitude(samples: Array, base: float) -> float:
	if samples.is_empty():
		return 0.0
	var lo := 1e9
	var hi := -1e9
	for v in samples:
		var f: float = float(v) / base
		lo = minf(lo, f); hi = maxf(hi, f)
	return hi - lo

func _style_id(name: String) -> int:
	match name:
		"WALK": return 0
		"RUN": return 1
		"AMBUSH": return 2
		"FLOAT": return 3
		"SPLIT": return 4
		"ELITE": return 5
		"BOSS": return 6
	return 0

func _probe_pulses() -> void:
	var st = load("res://assets/data/enemy_corroder.tres")
	var e := _make_enemy(st)
	var anim = e.get("anim")
	# 受击脉冲
	anim.call("pulse_hit")
	await _frames(3)
	_check(float(anim.get("_pulse_t")) > 0.0, "PULSE_HIT_ACTIVE")
	# 开火脉冲带方向
	anim.call("pulse_fire", Vector2.RIGHT)
	var d: Vector2 = anim.get("_pulse_dir")
	_check(d.is_equal_approx(Vector2.RIGHT), "PULSE_FIRE_DIR")
	# 破土 / 冲锋 / 咏唱 / 技能释放各能触发
	for m in ["pulse_emerge", "pulse_charge", "pulse_cast", "pulse_attack"]:
		anim.call(m, Vector2.RIGHT) if m == "pulse_attack" else anim.call(m)
		_check(int(anim.get("_pulse")) > 0, "PULSE_%s" % m.to_upper())
	# 受击时不应改 modulate（tint 染色由 Enemy 管，动画层只碰 transform）
	var spr: Sprite2D = e.get_node("Sprite")
	var before: Color = spr.modulate
	anim.call("pulse_hit")
	await _frames(4)
	_check(spr.modulate.is_equal_approx(before), "ANIM_NEVER_TOUCHES_MODULATE")
	e.queue_free()

func _probe_reuse() -> void:
	# 模拟 ObjectPool：同一实例换一只怪，动画相位/脉冲必须清零、变换回到基准
	var e := _make_enemy(load("res://assets/data/enemy_boss.tres"))
	var anim = e.get("anim")
	await _frames(20)
	anim.call("pulse_hit")
	await _frames(2)
	e.call("configure", load("res://assets/data/enemy_bloom.tres"))
	var spr: Sprite2D = e.get_node("Sprite")
	var base: Vector2 = e.get("_base_scale")
	_check(float(anim.get("_t")) == 0.0, "REUSE_PHASE_RESET")
	_check(float(anim.get("_pulse_t")) == 0.0, "REUSE_PULSE_CLEAR")
	_check(spr.scale.is_equal_approx(base), "REUSE_SCALE_BASE")
	_check(spr.rotation == 0.0 and spr.position == Vector2.ZERO, "REUSE_TRANSFORM_ZERO")
	_check(int(anim.get("_style")) == _style_id("FLOAT"), "REUSE_STYLE_CHANGED")
	e.queue_free()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1
		print("PASS ", label)
	else:
		_fail(label)

func _fail(label: String) -> void:
	failc += 1
	print("FAIL ", label)
