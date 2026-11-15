extends RefCounted
class_name FramePlayer
# 帧序列播放器 —— 全部运动的唯一来源是 FrameClip 里按序排列的帧图片。
#
# 与旧的 EnemyAnim.gd 的根本区别：
#   旧：每帧用数学公式算 scale / rotation / position（程序化动画）
#   新：只按时间推进帧下标，切换 Sprite.texture —— 不做任何几何变换
#
# 状态覆盖：
#   LOADING  帧图尚未加载完：显示占位静态贴图，不播放
#   READY    正常播放
#   MISSING  帧序列资源缺失：永久回退到静态贴图，并登记一次告警，绝不崩溃
#
# 尺寸与交互契约：
#   - 绝不写 scale / rotation / position / modulate，Sprite 与 Outline 的变换
#     完全保持 _apply_visual() 设定的基准值，因此界面尺寸与碰撞行为不变。
#   - 只同步写 Sprite.texture 与 Outline.texture。

enum State { LOADING, READY, MISSING }

const BASE_DIR := "res://assets/anim/"
const FRAME_FMT := "res://assets/anim/%s/%s/frame_%03d.png"
const DEFAULT_FRAMES := 4
const DEFAULT_FPS := 12.0

var state: int = State.LOADING
var key: String = ""
var fallback: Texture2D          # 资源缺失 / 加载中时用的静态原贴图
var _spr: Sprite2D
var _outline: Sprite2D
var _clips: Dictionary = {}      # 名称 -> FrameClip
var _current: String = ""
var _loop_clip: String = "loop"
var _index: int = 0
var _acc: float = 0.0
var _missing_reported: bool = false
var _pending_load: bool = true

# 全局缺失统计（便于探针与线上排查）
static var missing_keys: Dictionary = {}
static var loaded_keys: Dictionary = {}

func setup(spr: Sprite2D, outline: Sprite2D, enemy_key: String, still: Texture2D) -> void:
	_spr = spr
	_outline = outline
	key = enemy_key
	fallback = still
	_clips.clear()
	_current = ""
	_index = 0
	_acc = 0.0
	_missing_reported = false
	_pending_load = true
	state = State.LOADING
	# 加载中：先显示静态原贴图作为占位，保证画面不空、尺寸不变
	_apply_texture(fallback)

func _load_all() -> void:
	# 两套序列：loop（循环行走/待机）、act（单次攻击/受击/破土/技能）
	# 帧序列约定：frame_001.png … frame_004.png，按数字升序。
	var loop_clip := _load_clip("loop", true)
	var act_clip := _load_clip("act", false)
	if loop_clip == null and act_clip == null:
		state = State.MISSING
		if not _missing_reported:
			_missing_reported = true
			FramePlayer.missing_keys[key] = true
		push_warning("帧序列缺失，回退静态贴图: " + key)
		return
	if loop_clip != null:
		_clips["loop"] = loop_clip
	if act_clip != null:
		_clips["act"] = act_clip
	state = State.READY
	FramePlayer.loaded_keys[key] = true
	play(_loop_clip, true)

func _load_clip(clip: String, loop: bool) -> FrameClip:
	var list: Array[Texture2D] = []
	for i in range(1, DEFAULT_FRAMES + 1):
		var p := FRAME_FMT % [key, clip, i]
		if not ResourceLoader.exists(p):
			return null
		var tex := load(p) as Texture2D
		if tex == null:
			return null
		list.append(tex)
	var c := FrameClip.new()
	c.clip_name = clip
	c.frames = list
	c.fps = DEFAULT_FPS
	c.loop = loop
	return c

# 播放触发：显式切换到某条剪辑。
#   force_restart = true 时即便已在播该剪辑也从头开始（用于重复受击/连击）。
func play(clip_name: String, force_restart: bool = false) -> void:
	if state == State.MISSING:
		return
	if not _clips.has(clip_name):
		# 请求了不存在的剪辑：退回循环剪辑，不打断游戏
		clip_name = _loop_clip if _clips.has(_loop_clip) else _clips.keys()[0]
	if _current == clip_name and not force_restart:
		return
	_current = clip_name
	_index = 0
	_acc = 0.0
	var c: FrameClip = _clips[clip_name]
	_apply_texture(c.texture_at(0))

# 单次动作统一入口：攻击 / 受击 / 破土 / 冲锋 / 技能释放
func play_once() -> void:
	if _clips.has("act"):
		play("act", true)

func tick(delta: float) -> void:
	# 首次 tick 才载入帧序列：setup 到首帧之间保持 LOADING + 静态占位贴图，
	# 这样「加载中」是真实可验证的状态，而不是被同步加载瞬间跳过。
	if _pending_load:
		_pending_load = false
		_load_all()
		if state == State.MISSING:
			return
	if state != State.READY:
		return
	if not is_instance_valid(_spr):
		return
	# 池化顺序坑：ObjectPool 先 reset_for_reuse 再 add_child，@onready 可能尚未赋值
	if not is_instance_valid(_outline) and is_instance_valid(_spr):
		_outline = _spr.get_parent().get_node_or_null("Outline") as Sprite2D
	var c: FrameClip = _clips.get(_current) as FrameClip
	if c == null or not c.is_valid():
		return
	_acc += delta
	var step := 1.0 / c.fps
	if _acc < step:
		return
	_acc -= step
	# 单帧推进，按序 +1，不跳帧
	var next := _index + 1
	if next > c.last_index():
		if c.loop:
			next = 0                      # 循环：回到帧001
		else:
			# 单次：停在末帧，播完自动切回循环剪辑
			_index = c.last_index()
			_apply_texture(c.texture_at(_index))
			play(_loop_clip, true)
			return
	_index = next
	_apply_texture(c.texture_at(_index))

func _apply_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	if is_instance_valid(_spr):
		_spr.texture = tex
	# 描边层必须跟着换帧，否则会残留上一帧的轮廓形状
	if is_instance_valid(_outline):
		_outline.texture = tex

# ---- 只读查询，供探针 / 调试 ----
func current_clip_name() -> String:
	return _current

func current_index() -> int:
	return _index

func current_frame_count() -> int:
	var c: FrameClip = _clips.get(_current) as FrameClip
	return c.frame_count() if c else 0

func current_fps() -> float:
	var c: FrameClip = _clips.get(_current) as FrameClip
	return c.fps if c else 0.0

func current_duration() -> float:
	var c: FrameClip = _clips.get(_current) as FrameClip
	return c.duration() if c else 0.0

func current_is_loop() -> bool:
	var c: FrameClip = _clips.get(_current) as FrameClip
	return c.loop if c else false

func current_texture() -> Texture2D:
	return _spr.texture if is_instance_valid(_spr) else null

func reset() -> void:
	_index = 0
	_acc = 0.0
