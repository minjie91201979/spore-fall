extends CharacterBody2D
# 主角控制 + 受伤/死亡 + 开火（§11.4.1 / §11.4.3）。
# 键盘 WASD/方向键 + 移动端虚拟摇杆（TouchInput.move_vector）合并驱动。
const SPEED: float = 220.0

@export var max_health: float = 100.0
@export var bullet_scene: PackedScene
@export var infinite_ammo: bool = true   # 垂直切片阶段弹药无限（关掉即恢复消耗制）

var health: float = 100.0
var ammo: int = 20
var is_dead: bool = false
var _last_dir: Vector2 = Vector2.RIGHT
var _fire_cd: float = 0.0

# 武器数值（由 GameState.weapon_level 派生，升级即刷新）
var fire_interval: float = 0.22
var bullet_damage: float = 12.0
var projectile_count: int = 1

@onready var flashlight: PointLight2D = $Flashlight
@onready var outline: Sprite2D = $Outline

func _ready() -> void:
	add_to_group("player")
	GameState.weapon_leveled.connect(_on_weapon_leveled)
	_apply_weapon_level()
	# 画质档位注册（§11.6）：描边 pass 与手电光都受档位控制
	Quality.register_outline(outline)
	Quality.register_light(flashlight)

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	if _fire_cd > 0.0:
		_fire_cd -= _delta
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dir += TouchInput.move_vector
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * SPEED
	if dir != Vector2.ZERO:
		_last_dir = dir.normalized()
		flashlight.rotation = dir.angle()
	move_and_slide()
	# 限制在竞技场范围内，避免走出地面看到灰色虚空
	global_position.x = clampf(global_position.x, -880.0, 880.0)
	global_position.y = clampf(global_position.y, -880.0, 880.0)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("attack"):
		fire()

# 公开的开火入口：键盘（attack 动作）与移动端 FIRE 按钮共用
func fire() -> void:
	if is_dead:
		return
	_attack()

func _attack() -> void:
	if _fire_cd > 0.0:
		return   # 统一冷却：键盘 echo / 触屏连点 / 自动连发都走这一个闸门
	_fire_cd = fire_interval
	if not infinite_ammo and ammo <= 0:
		return
	# 开火不做 hitstop（会拖慢全局时间轴），只给轻微屏震做反馈
	Juice.add_trauma(0.08)
	Sfx.play("shoot")
	# 对象池取子弹（§11.9），池缺失时退回 instantiate 兜底
	var pool: Node = get_tree().get_first_node_in_group("bullet_pool")
	# 多弹道散射：每发间开 0.16 弧度，奇数居中偶数对称
	for i in projectile_count:
		var dir: Vector2 = _last_dir.rotated((i - (projectile_count - 1) * 0.5) * 0.16)
		var b: Area2D
		if pool:
			b = pool.acquire(get_tree().current_scene) as Area2D
		else:
			b = bullet_scene.instantiate()
			get_tree().current_scene.add_child(b)
		b.setup(dir, bullet_damage)
		# 从身体边缘生成，避免卡在自身碰撞体里
		b.global_position = global_position + dir * 18.0

# 升级回调：按当前武器等级刷新数值
func _on_weapon_leveled(_lv: int) -> void:
	_apply_weapon_level()
	Juice.add_trauma(0.2)

func _apply_weapon_level() -> void:
	var lv: int = GameState.weapon_level
	bullet_damage = 12.0 * (1.0 + 0.45 * (lv - 1))
	fire_interval = 0.22 * pow(0.88, lv - 1)
	projectile_count = 1 + (1 if lv >= 3 else 0) + (1 if lv >= 6 else 0)

func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, max_health)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	Juice.add_trauma(0.3)
	Juice.haptic(28)
	Sfx.play("hurt")
	EventBus.player_hit.emit(amount)
	if health <= 0:
		_die()
	else:
		Juice.hitstop(0.04, 0.05)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	GameState.end_run()
	set_physics_process(false)
	outline.visible = false   # 描边是独立 pass，不吃 modulate 淡出，直接关掉防残影
	# 死亡演出：慢动作 + 镜头推近 + 玩家淡出（tween 用真实时间，不受 time_scale 影响）
	Engine.time_scale = 0.28
	Sfx.play("hurt", 0.62, 2.0)
	Juice.add_trauma(0.65)
	Juice.haptic(150)
	var cam := get_viewport().get_camera_2d()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.62).set_ease(Tween.EASE_OUT)
	if cam:
		tw.tween_property(cam, "zoom", Vector2(1.14, 1.14), 0.62).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.68, true, false, true).timeout
	Engine.time_scale = 1.0
	visible = false
