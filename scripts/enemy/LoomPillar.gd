extends Area2D
# §Wave3 P2「镜像反射柱」：Boss 进入 P2 时在场地生成的三根静态 Area2D。
# 设计契约（docs/wave3-boss-state-machine.md §三 P2）：
#   - 位于竞技场对角线对称点，玩家撞上去被弹到对映点 mirror_pos = 2*pillar.pos - player.pos
#   - P2 蓝色脉动 / P3 红色高频闪烁（反射柱闪烁频率 ×3）
#   - Boss 死亡时由 Enemy._clear_loom_effects 统一 queue_free，无状态残留
#
# 自身在 _ready() 里画出全部视觉（Polygon2D + 光晕），无需单独 .tscn。
# 传送冷却：玩家被弹到对映点后可能立刻碰到另一根柱，用 player meta 记 0.6s 冷却防乒乓。

const TELEPORT_CD_SEC: float = 0.6
const PILLAR_RADIUS: float = 34.0

var _phase: int = 2
var _t: float = 0.0
var _vis: Polygon2D
var _glow: Polygon2D

func configure(phase: int) -> void:
	_phase = phase
	_apply_phase_visual()

func _ready() -> void:
	add_to_group("loom_pillar")
	monitoring = true
	monitorable = false
	collision_layer = 0          # 不占物理层，只做 Area 检测
	collision_mask = 2           # 只感知玩家（Player collision_layer=2）
	var shape := CircleShape2D.new()
	shape.radius = PILLAR_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	_glow = Polygon2D.new()
	_glow.polygon = _octagon(PILLAR_RADIUS * 1.5)
	_glow.z_index = -1
	add_child(_glow)
	_vis = Polygon2D.new()
	_vis.polygon = _octagon(PILLAR_RADIUS)
	add_child(_vis)
	body_entered.connect(_on_body_entered)
	_apply_phase_visual()

func _apply_phase_visual() -> void:
	if _vis == null or _glow == null:
		return
	if _phase >= 3:
		_vis.color = Color(1.0, 0.28, 0.24, 0.72)   # P3 危险红
		_glow.color = Color(1.0, 0.18, 0.12, 0.22)
	else:
		_vis.color = Color(0.35, 0.72, 1.0, 0.55)    # P2 电蓝
		_glow.color = Color(0.25, 0.6, 1.0, 0.18)

func _process(delta: float) -> void:
	_t += delta
	if _vis == null:
		return
	# P2 慢脉动 3Hz / P3 高频 9Hz（×3），用 scale + alpha 双重提示
	var hz: float = 9.0 if _phase >= 3 else 3.0
	var pulse: float = 0.5 + 0.5 * sin(_t * TAU * hz)
	_vis.scale = Vector2.ONE * (1.0 + pulse * 0.16)
	_glow.scale = Vector2.ONE * (1.0 + pulse * 0.34)
	var base_a: float = 0.72 if _phase >= 3 else 0.55
	_vis.color.a = base_a * (0.72 + 0.28 * pulse)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = float(body.get_meta("loom_teleport_cd", -999.0))
	if now - last < TELEPORT_CD_SEC:
		return
	body.set_meta("loom_teleport_cd", now)
	# mirror_pos = 2*pillar.pos - player.pos（对角线对映点）
	var mirror_pos: Vector2 = 2.0 * global_position - body.global_position
	# 夹回竞技场边界（Arena NAV_HALF=900），避免弹飞出界
	mirror_pos.x = clampf(mirror_pos.x, -860.0, 860.0)
	mirror_pos.y = clampf(mirror_pos.y, -860.0, 860.0)
	# 传送是刚体瞬移，必须延迟到物理帧外改，避免与 move_and_slide 抢位置
	body.set_deferred("global_position", mirror_pos)
	Sfx.play("hit", 0.7, 6.0)
	Juice.add_trauma(0.22)
	body.set_meta("loom_teleported", true)   # 供探针断言

func set_phase(phase: int) -> void:
	_phase = phase
	_apply_phase_visual()

func _octagon(r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
