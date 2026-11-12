extends Control
# 局内三选一升级卡（§11.11）：攒满升级点 → 暂停 → 选卡 → 恢复。
#
# 为什么整个节点 process_mode = ALWAYS：暂停期间它自己还要收点击 / 键盘 1·2·3，
# 若用默认 PAUSABLE，UI 和游戏一起冻住，就再也点不动卡片了。
# 暂停只冻「玩法」，不冻「选择」，这是这类 Roguelite 升级弹窗的关键。

const CARD_COUNT := 3

var _queue: Array = []          # 极端情况下连续攒够两级，排队逐次弹，不互相覆盖
var _current: Array = []        # 当前展示的卡数据（<= 3）
var _cards: Array[Button] = []

@onready var level_label: Label = $Center/Eyebrow
@onready var hint_label: Label = $Center/Hint

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	for i in CARD_COUNT:
		var b: Button = get_node("Center/Cards/Card%d" % i) as Button
		_cards.append(b)
		var idx: int = i
		b.pressed.connect(func(): _choose(idx))
	GameState.upgrade_ready.connect(_on_upgrade_ready)
	GameState.game_over.connect(_on_game_over)

# ---------- 开卡 ----------
func _on_upgrade_ready(choices: Array) -> void:
	if choices.is_empty():
		return
	_queue.append(choices)
	if not visible:
		_open_next()

func _open_next() -> void:
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	for i in CARD_COUNT:
		var card: Button = _cards[i]
		if i >= _current.size():
			card.visible = false
			continue
		card.visible = true
		_fill_card(card, _current[i], i)
	level_label.text = "LEVEL %d   ·   孢 子 进 化" % GameState.weapon_level
	hint_label.text = "点击卡片选择　·　键盘 1 / 2 / 3"
	# 触屏层是 UILayer 之后的 CanvasLayer，会盖在遮罩上；先收起并复位其按住状态
	_set_touch_controls(false)
	get_tree().paused = true
	# 不做入场动画：暂停中的 Tween 推进受 process_mode 影响，宁可「立刻可读」
	modulate = Color.WHITE
	show()

func _fill_card(card: Button, data: Dictionary, index: int) -> void:
	var col: Color = data.color
	var icon: Label = card.get_node("Icon")
	var title: Label = card.get_node("Name")
	var desc: Label = card.get_node("Desc")
	var taken: Label = card.get_node("Taken")
	var badge: Label = card.get_node("Index")
	icon.text = data.icon
	title.text = data.name
	desc.text = data.desc
	taken.text = "已选 %d / %d" % [
		int(GameState.taken_upgrades.get(data.id, 0)), UpgradePool.max_taken(data.id)]
	badge.text = str(index + 1)
	icon.add_theme_color_override("font_color", col)
	title.add_theme_color_override("font_color", col)
	badge.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.75))
	# 边框按卡色着色：三张卡不用记文字也能一眼区分属性系
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var bright: float = 0.10 if state == "hover" else (0.16 if state == "pressed" else 0.055)
		sb.bg_color = Color(0.055 + col.r * bright, 0.07 + col.g * bright,
			0.09 + col.b * bright, 0.98)
		sb.set_border_width_all(2)
		sb.border_color = Color(col.r, col.g, col.b, 0.85 if state != "normal" else 0.55)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 14
		card.add_theme_stylebox_override(state, sb)

# ---------- 选卡 ----------
func _choose(index: int) -> void:
	if not visible or index < 0 or index >= _current.size():
		return
	var id: String = _current[index].id
	_close()
	GameState.apply_upgrade(id)
	Sfx.play("pickup")
	if not _queue.is_empty():
		_open_next()

func _close() -> void:
	hide()
	_current = []
	get_tree().paused = false
	_set_touch_controls(true)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# PC 键盘 1 / 2 / 3
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		var idx: int = -1
		match key.keycode:
			KEY_1, KEY_KP_1: idx = 0
			KEY_2, KEY_KP_2: idx = 1
			KEY_3, KEY_KP_3: idx = 2
		if idx >= 0 and idx < _current.size():
			_choose(idx)
			accept_event()
		return
	# 鼠标 / 触屏命中：手机端只有这条路，绝不能赌「暂停时 Button 还收不收 GUI 输入」。
	# 本节点是 ALWAYS，_input 一定会在暂停中被调用，所以自己按卡片矩形判定最稳。
	# 命中后 accept_event 拦下，Button 的 pressed 不会重复触发（_choose 也有 visible 守卫）。
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		var pos: Vector2 = event.position
		for i in mini(_current.size(), CARD_COUNT):
			if _cards[i].visible and _cards[i].get_global_rect().has_point(pos):
				_choose(i)
				accept_event()
				return

# ---------- 状态兜底 ----------
func _on_game_over(_score: int, _time: float) -> void:
	# 暂停时玩家不会掉血，但探针/直接调 end_run 可能绕过；无论如何别把暂停带进结算
	_queue.clear()
	_current = []
	if visible:
		hide()
	get_tree().paused = false
	_set_touch_controls(true)

func _set_touch_controls(enabled: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var tc := scene.get_node_or_null("TouchControls")
	if tc == null:
		return
	# 暂停中丢掉的松手事件会让「FIRE 一直按住」或「摇杆自己推着走」，
	# 关闭弹窗时统一复位，避免恢复瞬间角色乱跑 / 自动开火
	if tc.has_method("reset_input"):
		tc.reset_input()
	if enabled:
		tc.show()
	else:
		tc.hide()
