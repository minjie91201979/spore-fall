extends Control
# 标题背景：缓慢上浮的孢子浮尘。
# 纯 _draw 画圆（46 个），零贴图零节点开销；每个孢子独立速度/半径/相位，
# 横向用正弦漂移，看起来像空气里被搅动的浮尘，而不是匀速直线。

const COUNT := 46

var _px: Array[float] = []
var _py: Array[float] = []
var _pr: Array[float] = []
var _spd: Array[float] = []
var _phase: Array[float] = []
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs: Vector2 = size if size.x > 1.0 else get_viewport_rect().size
	for i in COUNT:
		_px.append(randf() * vs.x)
		_py.append(randf() * vs.y)
		_pr.append(randf_range(0.9, 2.8))
		_spd.append(randf_range(6.0, 22.0))
		_phase.append(randf() * TAU)

func _process(delta: float) -> void:
	_t += delta
	var h: float = size.y if size.y > 1.0 else get_viewport_rect().size.y
	var w: float = size.x if size.x > 1.0 else get_viewport_rect().size.x
	for i in COUNT:
		_py[i] -= _spd[i] * delta
		_px[i] += sin(_phase[i] + _t * 0.55) * 7.0 * delta
		if _py[i] < -10.0:
			_py[i] = h + 10.0
			_px[i] = randf() * w
	queue_redraw()

func _draw() -> void:
	for i in COUNT:
		var a: float = 0.09 + 0.13 * (_pr[i] / 2.8)
		draw_circle(Vector2(_px[i], _py[i]), _pr[i], Color(0.36, 0.92, 0.86, a))
