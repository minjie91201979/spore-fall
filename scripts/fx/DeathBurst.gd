class_name DeathBurst
extends Node2D
# 击杀爆裂演出（§11.4.3）：怪被"打爆" —— 闪白膨胀 + 冲击环 → 炸成贴图碎片 + 脓滴四散 → 淡出。
# 单 CanvasItem 纯 _draw 手动积分：零粒子节点、零 Tween 节点，死亡潮不炸画布。
# 池化本体立刻回池，视觉替身留原地播完自毁，不污染下次复用。
# 碎片状态用内部类对象保存（Dictionary 的嵌套值类型复合赋值不可靠，踩过坑）。
# 用法：DeathBurst.spawn(parent, pos, tex, tint, blood, spr_scale, size_mult)

const DURATION := 0.62      # 总时长
const POP_TIME := 0.10      # 阶段A：闪白膨胀
const GRAVITY := 420.0      # 碎片下坠
const DRAG := 2.2           # 空气阻力系数
const CAP := 24             # 同屏爆裂上限（超出回收最旧，防 100+ 同屏死亡潮）

class Shard:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var rot: float = 0.0
	var spin: float = 0.0
	var size: float = 0.0
	var region: Rect2 = Rect2()
	var kind: String = "shard"
	var delay: float = 0.0

var _tex: Texture2D
var _tint: Color = Color.WHITE
var _blood: Color = Color(0.2, 0.6, 0.5)
var _spr_scale: float = 0.19
var _size_mult: float = 1.0
var _t: float = 0.0
var _shards: Array[Shard] = []
var _low_quality: bool = false

static var _alive: Array[DeathBurst] = []

static func spawn(parent: Node, pos: Vector2, tex: Texture2D, tint: Color,
		blood: Color, spr_scale: float, size_mult: float = 1.0) -> DeathBurst:
	var d: DeathBurst = DeathBurst.new()
	d._tex = tex
	d._tint = tint
	d._blood = blood
	d._spr_scale = spr_scale
	d._size_mult = size_mult
	d.position = pos
	d.z_index = 5                # 爆裂演出压在角色上层，遮挡关系稳定
	d.z_as_relative = false
	parent.add_child(d)
	_alive.push_back(d)
	# 低画质档收缩碎片数（§11.6 联动，运行时取 Autoload）
	var q: Node = parent.get_tree().root.get_node_or_null("Quality")
	d._low_quality = q != null and int(q.get("level")) == 0
	d._make_shards()
	while _alive.size() > CAP:
		var oldest: DeathBurst = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	return d

func _make_shards() -> void:
	if _tex == null:
		return
	var n: int = 5 + int(round(_size_mult * 3.0))   # 杂兵 5~6 片，Boss 倍增至 ~13 片
	if _low_quality:
		n = maxi(3, n / 2)
	for i in n:
		var sh := Shard.new()
		var a: float = randf() * TAU
		var sp: float = randf_range(110.0, 260.0) * (0.8 + 0.35 * _size_mult)
		sh.vel = Vector2(cos(a), sin(a)) * sp - Vector2(0.0, 55.0)  # 略向上炸开
		sh.rot = randf() * TAU
		sh.spin = randf_range(-9.0, 9.0)
		sh.size = randf_range(9.0, 18.0) * sqrt(_size_mult)
		sh.region = _random_region()
		sh.delay = randf_range(0.0, 0.04)
		_shards.push_back(sh)
	# 脓滴：血色小圆，带出「体液炸开」的湿润感
	for i in maxi(2, n / 2):
		var drop := Shard.new()
		var a: float = randf() * TAU
		var sp: float = randf_range(70.0, 190.0) * sqrt(_size_mult)
		drop.vel = Vector2(cos(a), sin(a)) * sp - Vector2(0.0, 30.0)
		drop.size = randf_range(2.5, 5.5) * sqrt(_size_mult)
		drop.kind = "drop"
		_shards.push_back(drop)

# 从贴图主体区（256 画布中心约 210px）随机取一小块，碎片自带怪的像素纹理
func _random_region() -> Rect2:
	var ts: Vector2 = _tex.get_size()
	var margin: float = ts.x * 0.09
	var inner: Vector2 = ts - Vector2.ONE * margin * 2.0
	var w: float = randf_range(inner.x * 0.18, inner.x * 0.36)
	var h: float = w * randf_range(0.7, 1.2)
	return Rect2(margin + randf() * (inner.x - w), margin + randf() * (inner.y - h), w, h)

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		_expire()
		return
	if _t > POP_TIME:
		for sh in _shards:
			if sh.delay > 0.0:
				sh.delay -= delta
				continue
			sh.vel.y += GRAVITY * delta
			sh.vel *= maxf(0.0, 1.0 - DRAG * delta)
			sh.pos += sh.vel * delta
			sh.rot += sh.spin * delta
	queue_redraw()

func _draw() -> void:
	if _tex == null:
		return
	# 显式清掉上一帧命令：A→B 阶段切换时若沿用旧命令，阶段A的完整贴图会一直挂在画面上
	# （Godot 4 的 canvas item 命令在 queue_redraw 之间会保留，表现成「怪没炸开」）
	RenderingServer.canvas_item_clear(get_canvas_item())
	# 阶段A：强闪白 + 1.55 倍膨胀 + 冲击环（一眼读懂「被打爆」）
	if _t < POP_TIME:
		var k: float = _t / POP_TIME
		var s: float = _spr_scale * (1.0 + 0.55 * k)
		# modulate 是乘法调制：乘 Color.WHITE 只是原色，必须 >1 过曝才能烧成白剪影
		var flash: Color = Color(2.6, 2.6, 2.6, 1.0).lerp(
			_tint, clampf((k - 0.7) / 0.3, 0.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * s)
		draw_texture(_tex, -_tex.get_size() * 0.5, flash)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ring_r: float = (18.0 + 34.0 * k) * sqrt(_size_mult)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 24,
			Color(1.0, 1.0, 1.0, 0.9 * (1.0 - k)), 3.0)
		return
	# 阶段B：碎片 + 脓滴四散，随时间淡出
	var life: float = clampf(1.0 - (_t - POP_TIME) / (DURATION - POP_TIME), 0.0, 1.0)
	# 冲击环余波：快速扩张并淡出，衔接 A/B 两阶段
	var ring_k: float = clampf((_t - POP_TIME) / 0.16, 0.0, 1.0)
	if ring_k < 1.0:
		draw_arc(Vector2.ZERO, (52.0 + 46.0 * ring_k) * sqrt(_size_mult), 0.0, TAU, 24,
			Color(1.0, 1.0, 1.0, 0.45 * (1.0 - ring_k)), 2.0)
	for sh in _shards:
		if sh.delay > 0.0:
			continue
		if sh.kind == "shard":
			var rs: Vector2 = sh.region.size
			var sc: float = sh.size / maxf(rs.x, 1.0)
			draw_set_transform(sh.pos, sh.rot, Vector2.ONE * sc)
			var c: Color = Color(_tint.r, _tint.g, _tint.b, _tint.a * life)
			draw_texture_rect_region(_tex, Rect2(-rs * 0.5, rs), sh.region, c)
		else:
			draw_set_transform(sh.pos, 0.0, Vector2.ONE)
			draw_circle(Vector2.ZERO, sh.size * (0.6 + 0.4 * life),
				Color(_blood.r, _blood.g, _blood.b, life * 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _expire() -> void:
	_alive.erase(self)
	queue_free()

func _exit_tree() -> void:
	_alive.erase(self)
