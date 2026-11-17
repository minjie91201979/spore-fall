extends Node2D
# 拾取掉落（§11.10 类）：heal 医疗包回血 / crystal 孢子晶体加分 / weapon 武器箱换新枪。
# 纯 Node2D + 距离判定，不走物理层（吸取上一轮教训：能不碰物理就不碰物理）。
# 行为：90px 内磁吸向玩家 → 22px 内拾取；12s 寿命，末 3s 闪烁提醒过期。

@export_enum("heal", "crystal", "weapon", "ammo", "false") var kind: String = "crystal"
# weapon 类型专用：要发放的武器 id（掉落方填好；空串在拾取时兜底随机）
var weapon_id: String = ""
# 剧情定点弹药箱。生存局误刷时不发子弹，改给一颗晶体。
var ammo_amount: int = 12
# 任务道具不随 12 秒寿命消失
var persistent: bool = false
# 伪晶体（§11.15 False Bloom）扣血惩罚值，默认读 stats
var fake_hp_penalty: float = -1.0   # <0 表示未配置，拾取时用 fallback 30.0

const MAGNET_RADIUS := 90.0
const COLLECT_RADIUS := 22.0
const LIFETIME := 12.0
const HEAL_AMOUNT := 25.0
const CRYSTAL_SCORE := 25
const MAGNET_SPEED := 260.0

var _player: Node2D
var _life: float = LIFETIME
var _t: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO
var _collected: bool = false

@onready var heal_vis: Polygon2D = $HealVis
@onready var heal_cross: Polygon2D = $HealCross
@onready var crystal_vis: Polygon2D = $CrystalVis
@onready var crystal_core: Polygon2D = $CrystalCore
@onready var weapon_vis: Polygon2D = $WeaponVis
@onready var weapon_shine: Polygon2D = $WeaponShine
@onready var weapon_icon: Sprite2D = $WeaponIcon

func _ready() -> void:
	add_to_group("pickup")
	_player = get_tree().get_first_node_in_group("player")
	# 先记基准位再挂动画（入场时 global_position 已由生成方摆好）
	_base_pos = global_position
	_apply_visual()

func _apply_visual() -> void:
	var is_heal := kind == "heal"
	var is_wpn := kind == "weapon"
	var is_ammo := kind == "ammo"
	var is_false := kind == "false"
	heal_vis.visible = is_heal
	heal_cross.visible = is_heal
	crystal_vis.visible = kind == "crystal" or is_ammo or is_false
	crystal_core.visible = kind == "crystal" or is_ammo or is_false
	if is_ammo:
		crystal_vis.color = Color(0.86, 0.62, 0.22)
		crystal_core.color = Color(0.98, 0.86, 0.45)
	elif is_false:
		# 伪晶体橙光微差（Wave 3 §11.15），与真晶体的青色区分
		crystal_vis.color = Color(1.0, 0.55, 0.1)
		crystal_core.color = Color(1.0, 0.78, 0.35)
	weapon_vis.visible = is_wpn
	weapon_shine.visible = is_wpn
	weapon_icon.visible = is_wpn
	if is_wpn:
		# 空串兜底：随机挑一把未拥有的（全收集时退回晶体，在 _collect 前判定）
		if weapon_id == "":
			weapon_id = WeaponDB.random_unowned(GameState.owned_weapons)
			if weapon_id == "":
				kind = "crystal"
				_apply_visual()
				return
		weapon_icon.texture = WeaponDB.icon_of(weapon_id)

func _physics_process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	# 上下浮动（爽刷的 juice 细节）；武器箱多加一点旋转的「贵重感」
	position = _base_pos + Vector2(0.0, sin(_t * 3.0) * 3.0)
	if kind == "weapon":
		weapon_icon.rotation = sin(_t * 2.2) * 0.12
	# 寿命倒数 + 末 3s 闪烁。定点补给箱留在场景里，直到被捡走。
	if not persistent:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		visible = _life > 3.0 or fmod(_life, 0.3) > 0.15
	# §Wave3 P3 覆写协议：冻结期间晶体停在原地，玩家贴上去也吸不动、捡不了
	if GameState.pickup_frozen:
		modulate.a = 0.45 + 0.25 * sin(_t * 8.0)   # 灰暗闪烁提示「被覆写」
		return
	modulate.a = 1.0
	# 磁吸 + 拾取（玩家死亡后不再吸）
	if is_instance_valid(_player) and not _player.get("is_dead"):
		var d: float = global_position.distance_to(_player.global_position)
		if d < magnet_radius():
			_base_pos = _base_pos.move_toward(_player.global_position, delta * MAGNET_SPEED)
		if d < COLLECT_RADIUS:
			_collect()

# 每帧读乘区：选完「引力场」后场上已存在的晶体也立刻扩大吸附范围
func magnet_radius() -> float:
	return MAGNET_RADIUS * float(GameState.mods.magnet)

func _collect() -> void:
	_collected = true
	Sfx.play("pickup")
	if kind == "heal":
		if _player and _player.has_method("heal"):
			_player.heal(HEAL_AMOUNT)
	elif kind == "weapon":
		var acquired: bool = GameState.acquire_weapon(weapon_id)
		if not acquired:
			# 已拥有（如另一只怪也掉了同一把）：折算 3 颗晶体补偿
			if not GameState.is_story():
				GameState.score += CRYSTAL_SCORE * 3
			GameState.add_crystal()
			GameState.add_crystal()
			GameState.add_crystal()
	elif kind == "ammo":
		if _player and _player.get("infinite_ammo"):
			GameState.add_crystal()
		elif _player:
			_player.ammo += ammo_amount
			EventBus.pickup_collected.emit("ammo", ammo_amount)
	elif kind == "false":
		# §11.15 伪孢孢诱饵：拾取反扣血 + toast 提示「腐化结晶」
		Sfx.play("hit", 0.5, 1.0)
		Juice.add_trauma(0.08)
		var penalty: float = HEAL_AMOUNT if fake_hp_penalty < 0 else absf(fake_hp_penalty)
		if _player and _player.has_method("take_damage"):
			_player.take_damage(penalty)
		EventBus.corrupt_pickup.emit(penalty)
	else:
		# 剧情晶体只进货币，不加生存分数
		if not GameState.is_story():
			GameState.score += CRYSTAL_SCORE
		GameState.add_crystal()   # 晶体同时是武器升级货币（攒满自动升级）
	# 放大淡出小爆闪
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.10)
	tw.tween_callback(queue_free)
