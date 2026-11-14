extends Control
# 无尽模式 HUD（§11.6 / §7）：分数 / 连杀 / 存活时长 / 弹药 + 受击红屏脉冲。
@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var time_label: Label = $TimeLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var quality_button: Button = $QualityButton
@onready var toast_label: Label = $ToastLabel
var _toast_tw: Tween
var _objective: Label
var _keys: Label
@onready var tier_label: Label = $TierLabel
@onready var boss_warn: ColorRect = $BossWarn
var _dry: float = 0.0
var _ammo_pos := Vector2(20, 134)
var _weapon_pos := Vector2(20, 172)
var settings_button: Button

func _ready() -> void:
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.quality_changed.connect(_on_quality_changed)
	EventBus.achievement_unlocked.connect(_on_achievement)
	EventBus.weapon_dry_fired.connect(_on_dry_fire)
	EventBus.pickup_collected.connect(_on_pickup)
	GameState.weapon_leveled.connect(_on_weapon_leveled)
	GameState.upgrade_applied.connect(_on_upgrade_applied)
	GameState.game_over.connect(_on_game_over)
	GameState.weapon_acquired.connect(_on_weapon_acquired)
	GameState.difficulty_changed.connect(_on_difficulty_changed)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	quality_button.pressed.connect(_on_quality_pressed)
	# 设置按钮放在「画质」正下方，沿用同一套 ghost 样式
	settings_button = MenuChrome.ghost_button("设 置")
	settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -150.0
	settings_button.offset_top = 64.0
	settings_button.offset_right = -20.0
	settings_button.offset_bottom = 100.0
	settings_button.custom_minimum_size = Vector2(130, 36)
	settings_button.add_theme_font_size_override("font_size", 14)
	settings_button.focus_mode = Control.FOCUS_NONE
	add_child(settings_button)
	settings_button.pressed.connect(_on_settings_pressed)
	_update_quality_text()
	add_to_group("hud")
	_ammo_pos = ammo_label.position
	_weapon_pos = weapon_label.position
	_objective = Label.new()
	_objective.name = "ObjectiveLabel"
	_objective.position = Vector2(20, 20)
	_objective.add_theme_font_size_override("font_size", 18)
	_objective.add_theme_color_override("font_color", Color(0.7, 0.95, 0.9))
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.visible = false
	add_child(_objective)
	_keys = Label.new()
	_keys.name = "KeyLabel"
	_keys.position = Vector2(420, 20)
	_keys.add_theme_font_size_override("font_size", 14)
	_keys.add_theme_color_override("font_color", Color(0.78, 0.86, 0.55))
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.visible = false
	add_child(_keys)

func _on_quality_pressed() -> void:
	Quality.cycle()

func _on_settings_pressed() -> void:
	SettingsPanel.open_from(self)

func _on_quality_changed(_lv: int) -> void:
	_update_quality_text()

func _update_quality_text() -> void:
	quality_button.text = "画质 %s" % Quality.LEVEL_NAMES[Quality.level]
func _on_difficulty_changed(tier: int) -> void:
	var color := Color(0.95, 0.95, 0.95)
	if tier >= 4:
		color = Color(0.98, 0.32, 0.22)
	elif tier >= 2:
		color = Color(0.95, 0.70, 0.30)
	tier_label.text = "TIER %s" % ["I", "II", "III", "IV"][min(tier, 3)]
	tier_label.add_theme_color_override("font_color", color)
func _on_boss_spawned(_name: String, _max_hp: float) -> void:
	Sfx.play("alarm")
	boss_warn.modulate.a = 0.0
	boss_warn.visible = true
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	for _i in 6:
		tw.tween_property(boss_warn, "modulate:a", 0.32, 0.12)
		tw.tween_property(boss_warn, "modulate:a", 0.0, 0.18)
func _on_boss_defeated(_name: String) -> void:
	boss_warn.visible = false


func _on_weapon_acquired(id: String) -> void:
	# 捡到新武器：金色 toast + 武器栏自动加格子并切换
	if GameState.is_story():
		_show_toast("获得武器　%s" % WeaponDB.name_of(id), Color(1.0, 0.85, 0.3))
	else:
		_show_toast("获得新武器：%s" % WeaponDB.name_of(id), Color(1.0, 0.85, 0.3))


func _on_game_over(_score: int, _time: float) -> void:
	# 死亡时让 HUD 淡出，给结算层让位
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.3, true, false, true).timeout
	boss_warn.visible = false
	hide()

func _on_player_hit(_dmg: int) -> void:
	# 受击红屏脉冲（§7）
	damage_flash.modulate.a = 0.5
	var t := create_tween()
	t.tween_property(damage_flash, "modulate:a", 0.0, 0.35)

# 顶部固定绝对定位 toast：不 push 任何布局；后来的消息 kill 旧 tween 直接接管同一条时间轴。
# 成就与升级卡共用一条，避免两条提示叠在一起互相盖住。
func _show_toast(text: String, col: Color) -> void:
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", col)
	toast_label.modulate.a = 0.0
	_toast_tw = create_tween()
	_toast_tw.set_ignore_time_scale(true)
	_toast_tw.tween_property(toast_label, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(2.2)
	_toast_tw.tween_property(toast_label, "modulate:a", 0.0, 0.45)

func _on_achievement(name: String) -> void:
	_show_toast("★ 成就解锁　" + name, Color(1.0, 0.84, 0.35, 1))

func _on_upgrade_applied(id: String) -> void:
	var card: Dictionary = UpgradePool.by_id(id)
	if not card.is_empty():
		_show_toast("✓ 获得强化　" + card.name, card.color)
	_on_weapon_leveled(GameState.weapon_level)

func _on_weapon_leveled(_lv: int) -> void:
	# 升级金色脉冲
	weapon_label.modulate = Color(1.0, 0.85, 0.3)
	weapon_label.scale = Vector2(1.35, 1.35)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(weapon_label, "modulate", Color.WHITE, 0.6)
	t.tween_property(weapon_label, "scale", Vector2.ONE, 0.3)

func _on_dry_fire() -> void:
	_dry = 0.28

func _on_pickup(type: String, amount: int) -> void:
	if not GameState.is_story():
		return
	if type == "ammo":
		_show_toast("弹药 +%d" % amount, Color(0.95, 0.82, 0.4))

func show_story_toast(text: String) -> void:
	_show_toast(text, Color(0.75, 0.95, 0.9))

func _process(delta: float) -> void:
	if _dry > 0.0:
		_dry -= delta
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		ammo_label.remove_theme_color_override("font_color")
	if not GameState.is_running:
		return
	var story := GameState.is_story()
	score_label.visible = not story
	combo_label.visible = not story
	time_label.visible = not story
	if _objective:
		_objective.visible = story and GameState.objective_text != ""
		_objective.text = GameState.objective_text
	if _keys:
		# 运行时再取剧情存档，避免 HUD 在 Autoload 注册前编译依赖 StoryState。
		var keys := ""
		if story:
			var story_state := get_node_or_null("/root/StoryState")
			if story_state:
				keys = str(story_state.get("key_text"))
		_keys.visible = story and keys != ""
		_keys.text = keys
	if story:
		ammo_label.position = Vector2(20, 58)
		weapon_label.position = Vector2(20, 96)
	else:
		ammo_label.position = _ammo_pos
		weapon_label.position = _weapon_pos
	tier_label.visible = not story
	boss_warn.visible = false
	if not story:
		score_label.text = "SCORE %06d" % GameState.score
		combo_label.text = "COMBO x%d" % GameState.combo
		time_label.text = "%.1f" % GameState.survived_time
	var player = get_tree().get_first_node_in_group("player")
	if player and "ammo" in player:
		if player.get("infinite_ammo"):
			ammo_label.text = "AMMO ∞"
		else:
			ammo_label.text = "AMMO %02d" % player.ammo
	if story:
		weapon_label.text = WeaponDB.name_of(GameState.current_weapon)
	else:
		weapon_label.text = "WEAPON LV%d  %d/%d  ·  BUILD %d" % [
			GameState.weapon_level, GameState.crystals, GameState.crystals_for_next(),
			GameState.upgrades_taken]
