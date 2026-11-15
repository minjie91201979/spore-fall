extends RefCounted
# 敌人程序化动画层（§11.14）：squash & stretch / 步态摆动 / 悬浮 / 蓄力 / 前冲 / 咏唱。
#
# 设计取舍
# --------
# 本作 13 种敌人都是「单张写实概念图」贴图、俯视角、屏幕尺寸约 40px。为它们各生成
# 4~8 帧逐帧图既难保持 AI 出图一致性，又会让资源与包体翻倍。这里改用纯数学变换：
#   - 零新资源、零额外 draw call，13 怪 + 3 BOSS 全覆盖，低画质档不掉帧；
#   - 只写 Sprite / Outline 的 scale / rotation / position / offset，
#     **绝不碰 modulate** —— 相乘染色(stats.tint) 与 _flash_tint 前摇染色由 Enemy 自己管；
#   - 持续姿态直接读宿主的 _charge_state / _ranged_state / _ambush_state，
#     不需要在每个状态切换点插桩，也不会漏分支；
#   - 瞬时事件（开火 / 受击 / 破土 / 冲锋起手 / 技能咏唱）由 pulse() 触发，带衰减。
#
# 池化：Enemy.reset_for_reuse() / configure() 会调 setup()，把相位与所有脉冲清零。

enum Style { WALK, RUN, AMBUSH, FLOAT, SPLIT, ELITE, BOSS }
enum Pulse { NONE, FIRE, HIT, EMERGE, CHARGE, CAST }

const TAU2 := TAU

var _spr: Sprite2D
var _outline: Sprite2D
var _base_scale: Vector2 = Vector2.ONE
var _style: int = Style.WALK
var _is_ranged: bool = false

var _t: float = 0.0
var _pulse: int = Pulse.NONE
var _pulse_t: float = 0.0
var _pulse_dur: float = 0.2
var _pulse_dir: Vector2 = Vector2.RIGHT
var _ready: bool = false

func setup(spr: Sprite2D, outline: Sprite2D, base_scale: Vector2, st: EnemyStats) -> void:
	_spr = spr
	_outline = outline
	_base_scale = base_scale
	_style = _style_of(st)
	_is_ranged = st != null and st.ranged_attack != ""
	_ready = true
	reset()

func _style_of(st: EnemyStats) -> int:
	if st == null:
		return Style.WALK
	if st.is_boss or st.behavior == "boss":
		return Style.BOSS
	match st.behavior:
		"ambush": return Style.AMBUSH
		"miasma": return Style.FLOAT
		"split": return Style.SPLIT
		"elite": return Style.ELITE
		"walk", "boss":
			if st.move_speed >= 115.0:
				return Style.RUN
			return Style.WALK
	return Style.WALK

# 池化复用 / 换怪时调用：清相位与脉冲，把变换还原到基准
func reset() -> void:
	_t = 0.0
	_pulse = Pulse.NONE
	_pulse_t = 0.0
	_apply(Vector2.ONE, 0.0, Vector2.ZERO)

func pulse(kind: int, dir: Vector2 = Vector2.RIGHT, dur: float = 0.2) -> void:
	_pulse = kind
	_pulse_dur = maxf(dur, 0.02)
	_pulse_t = _pulse_dur
	_pulse_dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT

# 语义化包装：Enemy.gd 无需通过实例访问枚举，避免 GDScript 版本差异
func pulse_fire(dir: Vector2) -> void:
	pulse(Pulse.FIRE, dir, 0.18)

func pulse_hit() -> void:
	pulse(Pulse.HIT, Vector2.RIGHT, 0.16)

func pulse_emerge() -> void:
	pulse(Pulse.EMERGE, Vector2.UP, 0.24)

func pulse_charge() -> void:
	pulse(Pulse.CHARGE, Vector2.RIGHT, 0.22)

func pulse_cast() -> void:
	pulse(Pulse.CAST, Vector2.RIGHT, 0.3)

func pulse_attack(dir: Vector2) -> void:
	pulse(Pulse.FIRE, dir, 0.2)

# 每帧由 Enemy._physics_process 末尾调用。
# host 传 Enemy 本体，anim 只读取状态，不写回任何玩法变量。
func tick(delta: float, host: Node2D) -> void:
	if not _ready:
		return
	# 池化顺序坑：ObjectPool.acquire() 先调 reset_for_reuse() 再 add_child()，
	# 那一刻 @onready 的 Outline 尚未赋值，setup() 可能缓存到 null。
	# 进树后第一帧在这里补引用，保证描边层始终与本体同步。
	if not is_instance_valid(_spr):
		_spr = host.get_node_or_null("Sprite") as Sprite2D
	if not is_instance_valid(_outline):
		_outline = host.get_node_or_null("Outline") as Sprite2D
	if not is_instance_valid(_spr):
		return
	_t += delta
	var speed: float = host.velocity.length()

	# ---- 1. 基础步态 / 待机呼吸：不同 style 频率与幅度不同 ----
	var freq := 8.0
	var bob := 2.2
	var sway := 0.09
	var squash := 0.055
	match _style:
		Style.RUN:
			freq = 15.0; bob = 2.8; sway = 0.14; squash = 0.085
		Style.AMBUSH:
			freq = 4.0; bob = 0.9; sway = 0.03; squash = 0.03
		Style.FLOAT:
			freq = 2.6; bob = 3.6; sway = 0.0; squash = 0.04
		Style.SPLIT:
			freq = 11.0; bob = 1.6; sway = 0.07; squash = 0.10
		Style.ELITE:
			freq = 5.0; bob = 2.6; sway = 0.08; squash = 0.07
		Style.BOSS:
			freq = 3.2; bob = 2.4; sway = 0.05; squash = 0.05

	# 静止时降为「呼吸」，移动时才走完整步态
	var moving := clampf(speed / 60.0, 0.0, 1.0)
	var amp := 0.28 + 0.72 * moving
	var ph: float = sin(_t * freq)
	var ph2: float = sin(_t * freq * 2.0)
	var sy := 1.0 + squash * ph * amp
	var sx := 1.0 - squash * 0.62 * ph * amp
	var rot: float = sway * ph2 * amp * signf(host.velocity.x) if absf(host.velocity.x) > 1.0 else sway * 0.2 * sin(_t * 1.7)
	var off := Vector2(0.0, -absf(ph) * bob * amp)

	# 悬浮体：不落地、不摆，持续上下漂 + 缓慢呼吸
	if _style == Style.FLOAT:
		rot = 0.04 * sin(_t * 1.1)
		off.y = sin(_t * 2.2) * bob
		sx = 1.0 + 0.035 * sin(_t * 2.6)
		sy = 1.0 - 0.035 * sin(_t * 2.6)

	# 伏击潜伏：几乎静止，只有极缓呼吸（破土由 EMERGE 脉冲接管）
	var amb: int = int(host.get("_ambush_state"))
	if amb == 1:
		sx = 1.0 + 0.012 * sin(_t * 1.4)
		sy = 1.0 - 0.012 * sin(_t * 1.4)
		rot = 0.0
		off = Vector2.ZERO

	# ---- 2. 持续姿态：读现有状态机，不额外插桩 ----
	var charge: int = int(host.get("_charge_state"))   # 0追击/1冲锋前摇/2突进/3技能前摇
	var ranged: int = int(host.get("_ranged_state"))   # 0追击/1站桩蓄射
	if charge == 1:
		# 冲锋前摇：后仰压扁，像蓄力弹簧
		var k := clampf(float(host.get("_charge_t")) / 0.55, 0.0, 1.0)
		sx *= 1.0 + 0.16 * (1.0 - k)
		sy *= 1.0 - 0.20 * (1.0 - k)
		rot += 0.10 * signf(host.velocity.x)
	elif charge == 2:
		# 突进：沿冲锋方向拉长，速度感
		sx *= 1.32
		sy *= 0.84
		var cdir: Vector2 = host.get("_charge_dir")
		off -= cdir * 3.0
	elif charge == 3:
		# 技能咏唱：整只收紧 + 轻微高频颤动
		var w := 1.0 - 0.08 * (0.5 + 0.5 * sin(_t * 26.0))
		sx *= w; sy *= w
		rot += 0.02 * sin(_t * 30.0)
	if ranged == 1:
		# 站桩蓄射：向后坐 + 鼓胀（远程怪/喷吐怪可读的预警）
		var k2 := clampf(float(host.get("_ranged_t")) / 0.45, 0.0, 1.0)
		sx *= 1.0 + 0.13 * (1.0 - k2)
		sy *= 1.0 - 0.10 * (1.0 - k2)
		off.y += 1.4

	# ---- 3. 瞬时脉冲：开火 / 受击 / 破土 / 冲锋起手 / 技能释放，带衰减 ----
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - delta)
		var k3: float = _pulse_t / _pulse_dur
		match _pulse:
			Pulse.FIRE:
				# 朝射击方向猛地一顶
				off += _pulse_dir * 5.0 * k3
				sx *= 1.0 + 0.20 * k3
				sy *= 1.0 - 0.12 * k3
			Pulse.HIT:
				# 受击：横向挤压 + 抖动，不改 modulate（避免与 tint 染色打架）
				var j := sin(_t * 70.0) * 2.0 * k3
				off.x += j
				sx *= 1.0 - 0.16 * k3
				sy *= 1.0 + 0.14 * k3
			Pulse.EMERGE:
				# 破土：纵向拉伸弹出
				sx *= 1.0 - 0.14 * k3
				sy *= 1.0 + 0.30 * k3
				off.y -= 4.0 * k3
			Pulse.CHARGE:
				sx *= 1.0 + 0.24 * k3
				sy *= 1.0 - 0.18 * k3
			Pulse.CAST:
				var c := 1.0 + 0.18 * k3
				sx *= c; sy *= c

	_apply(Vector2(sx, sy), rot, off)

func _apply(scale_mult: Vector2, rot: float, off: Vector2) -> void:
	if not is_instance_valid(_spr):
		return   # setup 可能发生在 @onready 之前，tick() 会在首帧补引用
	var s := _base_scale * scale_mult
	_spr.scale = s
	_spr.rotation = rot
	_spr.position = off
	# 描边层必须同步变换，否则会与本体脱节（低画质档描边隐藏，同步也无害）
	if is_instance_valid(_outline):
		_outline.scale = s
		_outline.rotation = rot
		_outline.position = off
