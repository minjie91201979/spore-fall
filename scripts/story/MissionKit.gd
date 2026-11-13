extends Node
const StoryCopy = preload("res://scripts/story/StoryCopy.gd")
# 三张任务图共用的刷怪、字幕队列、阅读器和四位密码盘。不管生存 Arena。

const PICKUP: PackedScene = preload("res://scenes/world/Pickup.tscn")

var host: Node2D
var player: CharacterBody2D
var session: StorySession
var blocks: Array[Dictionary] = []
var seen: Dictionary = {}
var _queue: Array = []
var _pad: CanvasLayer
var _digits: Label
var _pad_title: String = ""
var _code: String = ""
var _expect: String = ""
var _on_ok: Callable = Callable()
var _pad_open: bool = false
var _paused: Array = []
var _health: float = -1.0
var _miasma: bool = false
var _splitter: bool = false
var _spitter: bool = false
var _door_line: bool = false

func setup(owner: Node2D, who: CharacterBody2D, box: StorySession) -> void:
	host = owner
	player = who
	session = box
	_build_pad()

func say(lines: Array, then: Callable = Callable()) -> void:
	if lines.is_empty():
		if then.is_valid():
			then.call()
		return
	if session.dialogue.active or session._busy_line:
		_queue.append({"lines": lines, "then": then})
		return
	session.say(lines, false, func() -> void:
		if then.is_valid():
			then.call()
		if is_inside_tree():
			_drain()
	)

func _drain() -> void:
	if _queue.is_empty() or not is_inside_tree():
		return
	var item: Dictionary = _queue.pop_front()
	say(item.lines, item.then)

func toast(text: String) -> void:
	session._toast(text)

func wall(center: Vector2, size: Vector2, color: Color = Color(0.13, 0.16, 0.2)) -> StaticBody2D:
	var body := StoryWorld.add_wall(host, center, size, color)
	blocks.append({"center": center, "size": size})
	return body

func bake(region: NavigationRegion2D) -> void:
	StoryWorld.bake(region, blocks)

func spawn(stats: EnemyStats, pos: Vector2, zone: String = "") -> Node2D:
	var pool: Node = host.get_node("EnemyPool")
	var e: Node2D = pool.acquire(host)
	e.configure(stats)
	e.global_position = pos
	if zone != "":
		e.set_meta("zone", zone)
	return e

func place_weapon(pos: Vector2, id: String) -> Node2D:
	var pk: Node2D = PICKUP.instantiate()
	pk.kind = "weapon"
	pk.weapon_id = id
	pk.persistent = true
	pk.position = pos
	host.add_child(pk)
	return pk

func place_ammo(pos: Vector2, amount: int) -> void:
	var pk: Node2D = PICKUP.instantiate()
	pk.kind = "ammo"
	pk.ammo_amount = amount
	pk.persistent = true
	pk.position = pos
	host.add_child(pk)

func place_heal(pos: Vector2) -> void:
	var pk: Node2D = PICKUP.instantiate()
	pk.kind = "heal"
	pk.persistent = true
	pk.position = pos
	host.add_child(pk)

func interact(pos: Vector2, prompt: String) -> Interactable:
	return StoryWorld.interactable(host, pos, prompt)

func read_file(id: String) -> void:
	var spec: Dictionary = StoryCopy.file_spec(id)
	if str(spec.title) == "":
		return
	var first := not StoryState.has_file(id)
	if first:
		StoryState.add_file(id)
		toast("获得文件　%s" % str(spec.title))
	var marks: PackedStringArray = spec.marks
	session.open_file(str(spec.title), str(spec.body), marks)

func note_combat(near_door: bool) -> void:
	if player == null or player.is_dead:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.get("active") or e.get("stats") == null:
			continue
		var who := str(e.stats.display_name)
		if player.global_position.distance_to(e.global_position) <= 240.0 and not seen.has(who):
			seen[who] = true
			toast(who)
		if not _splitter and who.contains("分裂孢") and player.global_position.distance_to(e.global_position) < 280.0:
			_splitter = true
			say(StoryCopy.on_splitter())
	if not _miasma:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e.get("stats"):
				continue
			if str(e.stats.display_name).contains("毒雾孢") and not e.get("active"):
				_miasma = true
				say(StoryCopy.on_miasma())
				break
	var hp := float(player.health)
	if _health < 0.0:
		_health = hp
	elif hp < _health - 0.5 and not _spitter:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e.get("active") or e.get("stats") == null:
				continue
			if str(e.stats.display_name).contains("毒针孢") and player.global_position.distance_to(e.global_position) < 460.0:
				_spitter = true
				say(StoryCopy.on_spitter())
				break
	_health = hp
	if near_door and not _door_line:
		_door_line = true
		say(StoryCopy.on_return_door())

func hold_zone(zone: String, axis: String, limit: float, toward_positive: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.get("active"):
			continue
		if str(e.get_meta("zone", "")) != zone:
			continue
		if axis == "x":
			if toward_positive and e.global_position.x > limit:
				e.global_position.x = limit
			elif not toward_positive and e.global_position.x < limit:
				e.global_position.x = limit
		elif toward_positive and e.global_position.y > limit:
			e.global_position.y = limit
		elif not toward_positive and e.global_position.y < limit:
			e.global_position.y = limit

func ask_code(expected: String, title: String, on_ok: Callable) -> void:
	if _pad_open or session._ui_blocking():
		return
	_expect = expected
	_on_ok = on_ok
	_code = ""
	_pad_title = title
	_digits.text = title + "\n____"
	_pad.visible = true
	_pad_open = true
	player.control_mode = 2
	_pause_enemies(true)

func _build_pad() -> void:
	_pad = CanvasLayer.new()
	_pad.layer = 45
	_pad.visible = false
	add_child(_pad)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_pad.add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -180.0
	box.offset_right = 180.0
	box.offset_top = -220.0
	box.offset_bottom = 220.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	_pad.add_child(box)
	_digits = MenuChrome.label("____", 22, MenuChrome.CYAN)
	_digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_digits)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for n in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
		grid.add_child(_digit_button(str(n)))
	grid.add_child(_digit_button("清除", true))
	grid.add_child(_digit_button("0"))
	grid.add_child(_digit_button("确认", true))
	var close := MenuChrome.ghost_button("关 闭")
	close.pressed.connect(_close_pad)
	box.add_child(close)

func _digit_button(text: String, wide: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(96 if wide else 72, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _press_code(text))
	return btn

func _press_code(text: String) -> void:
	if not _pad_open:
		return
	if text == "清除":
		_code = ""
	elif text == "确认":
		_submit()
		return
	elif _code.length() < 4:
		_code += text
	_refresh_digits()

func _refresh_digits() -> void:
	var shown := _code
	while shown.length() < 4:
		shown += "_"
	_digits.text = _pad_title + "\n" + shown

func _submit() -> void:
	if _code == _expect:
		var done := _on_ok
		_close_pad()
		if done.is_valid():
			done.call()
		return
	_code = ""
	_pad_title = "不对"
	_digits.text = "不对\n____"
	Sfx.play("hit", 0.5, -4.0)

func _close_pad() -> void:
	if not _pad_open:
		return
	_pad_open = false
	_pad.visible = false
	_pause_enemies(false)
	if session._locks == 0 and session.gameplay_unlocked and not player.is_dead:
		player.control_mode = 0

func _pause_enemies(pause: bool) -> void:
	if pause:
		_paused.clear()
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("active") and e.is_physics_processing():
				e.set_physics_process(false)
				_paused.append(e)
		return
	for e in _paused:
		if is_instance_valid(e) and e.get("active"):
			e.set_physics_process(true)
	_paused.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not _pad_open or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: int = key_event.keycode
	if key >= KEY_0 and key <= KEY_9:
		_press_code(str(key - KEY_0))
		get_viewport().set_input_as_handled()
	elif key >= KEY_KP_0 and key <= KEY_KP_9:
		_press_code(str(key - KEY_KP_0))
		get_viewport().set_input_as_handled()
	elif key == KEY_BACKSPACE:
		_code = _code.substr(0, maxi(0, _code.length() - 1))
		_refresh_digits()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_submit()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		_close_pad()
		get_viewport().set_input_as_handled()
