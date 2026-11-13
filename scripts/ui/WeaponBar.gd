extends HBoxContainer
# 底部武器栏（TouchControls CanvasLayer 内）：5 个固定槽位，展示已获得武器。
# - 未获得：暗色轮廓（disabled），玩家知道「还有枪可以捡」
# - 已获得：正常亮度，点击 / 按数字键切换
# - 当前持有：金色高亮 + 放大
# 槽位顺序永远跟 WeaponDB.ORDER 一致，新武器插入不会让格子跳动。

const SLOT_SIZE := 58.0

var _buttons: Dictionary = {}   # id -> Button

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for id in WeaponDB.ORDER:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.icon = WeaponDB.icon_of(id)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.focus_mode = Control.FOCUS_NONE   # 不抢空格开火键的焦点
		btn.disabled = false
		btn.pressed.connect(_on_slot_pressed.bind(id))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var lbl := Label.new()
		lbl.text = WeaponDB.name_of(id)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		box.add_child(btn)
		box.add_child(lbl)
		add_child(box)
		_buttons[id] = btn

	# 排版居中：等所有槽位建好后把自己拉到内容宽度
	await get_tree().process_frame
	custom_minimum_size = Vector2(size.x + 2.0, 0)

	GameState.weapon_acquired.connect(_on_weapon_acquired)
	GameState.weapon_switched.connect(_on_weapon_switched)
	GameState.game_over.connect(_on_game_over)
	_refresh()

func _on_slot_pressed(id: String) -> void:
	GameState.switch_weapon(id)

# 数字键 1~5 快速切换（键盘端）
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.physical_keycode) - int(KEY_1)
		if idx >= 0 and idx < WeaponDB.ORDER.size():
			GameState.switch_weapon(WeaponDB.ORDER[idx])

func _on_weapon_acquired(_id: String) -> void:
	_refresh()

func _on_weapon_switched(_id: String) -> void:
	_refresh()

func _on_game_over(_score: int, _time: float) -> void:
	# 结算页出现前整体淡出，跟 HUD 一起让位
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)

func _refresh() -> void:
	for id in _buttons:
		var btn: Button = _buttons[id]
		var owned: bool = GameState.owned_weapons.has(id)
		var current: bool = GameState.current_weapon == id
		btn.disabled = not owned
		if current:
			btn.modulate = Color(1.0, 0.88, 0.45)
			btn.scale = Vector2(1.12, 1.12)
			btn.pivot_offset = btn.size * 0.5
		elif owned:
			btn.modulate = Color(0.85, 0.85, 0.85, 0.95)
			btn.scale = Vector2.ONE
		else:
			btn.modulate = Color(0.30, 0.30, 0.34, 0.55)
			btn.scale = Vector2.ONE
