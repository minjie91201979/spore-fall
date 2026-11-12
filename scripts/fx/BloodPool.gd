class_name BloodPool
extends Node2D
# 死亡血水残迹：怪物死亡处留一滩对应颜色的体液渍（§11.4.3 击杀反馈补完）。
# 纯 _draw 程序化斑点（主斑 + 卫星溅点），无贴图无粒子，单 CanvasItem 开销。
# 生命周期：0.16s 溅开 → 摊平存留 3.6s → 1.1s 淡出 → 自毁。
# 用法：BloodPool.spawn(parent, pos, color, size_mult)，颜色由 EnemyStats.blood_color 数据驱动。

const SPREAD_TIME := 0.16   # 溅开动画
const LINGER_TIME := 3.6    # 完全摊平后的存留
const FADE_TIME := 1.1      # 淡出
const CAP_HIGH := 50        # 高/中档同屏血渍上限
const CAP_LOW := 20         # 低档收缩（画质档联动 §11.6）

var _color: Color = Color(0.2, 0.62, 0.55, 0.78)
var _size_mult: float = 1.0
# 斑点表 [偏移, 半径]：主斑居中，卫星溅点随机散布，构成不规则液渍轮廓
var _blobs: Array = []

static var _alive: Array[BloodPool] = []

static func spawn(parent: Node, pos: Vector2, color: Color, size_mult: float = 1.0) -> BloodPool:
	var bp: BloodPool = BloodPool.new()
	bp._color = Color(color.r, color.g, color.b, 0.78)
	bp._size_mult = size_mult
	bp.position = pos
	bp.z_index = -1          # 永远压在所有角色脚下（地面层）
	bp._make_blobs()
	parent.add_child(bp)
	_alive.push_back(bp)
	# 数量上限：画质档联动（§11.6），超出回收最旧（防极端刷怪局长局积累画布项）
	# 走 root.get_node 运行时取（--script 探针里 Autoload 标识符不可用）
	var cap: int = CAP_HIGH
	var q: Node = parent.get_tree().root.get_node_or_null("Quality")
	if q and int(q.get("level")) == 0:
		cap = CAP_LOW
	while _alive.size() > cap:
		var oldest: BloodPool = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	bp._play_lifecycle()
	return bp

func _make_blobs() -> void:
	# 主斑居中，卫星溅点随机散布；Boss（scale_mult 大）斑点更多更散
	_blobs.push_back([Vector2.ZERO, 16.0])
	var count: int = 3 + int(round(_size_mult * 2.0))
	for i in count:
		var a: float = randf() * TAU
		var d: float = randf_range(12.0, 13.0 + 14.0 * _size_mult)
		var r: float = randf_range(3.5, 4.5 + 4.0 * _size_mult)
		_blobs.push_back([Vector2(cos(a), sin(a)) * d, r])

func _draw() -> void:
	# 整体 y 压扁 0.82（地面液渍的透视感）；溅开动画动的是 self.scale，重绘只管形状
	var squash := Vector2(1.0, 0.82)
	for b in _blobs:
		var offset: Vector2 = b[0] * _size_mult
		var r: float = b[1] * _size_mult
		draw_set_transform(offset, 0.0, squash)
		draw_circle(Vector2.ZERO, r, _color)
	# 深色内芯：更小的一层深斑压住中心，做出「浓稠」层次
	draw_set_transform(Vector2.ZERO, 0.0, squash * 0.6)
	draw_circle(Vector2.ZERO, 16.0 * _size_mult, _darkened())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _darkened() -> Color:
	return Color(_color.r * 0.55, _color.g * 0.55, _color.b * 0.55, _color.a)

func _play_lifecycle() -> void:
	# 溅开：0.25 → 1.0 弹性放大（BACK 缓出，像液体被砸开）
	scale = Vector2.ONE * 0.25
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, SPREAD_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 存留 + 淡出 + 自毁（一条时间轴走完，不占 timer 节点）
	tw.tween_interval(LINGER_TIME)
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(_expire)

func _expire() -> void:
	_alive.erase(self)
	queue_free()

func _exit_tree() -> void:
	_alive.erase(self)   # 场景重载/手动清理时同步静态表
