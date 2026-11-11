extends CharacterBody2D
# 主角控制 + 受伤/死亡 + 开火（§11.4.1 / §11.4.3）。
# 键盘 WASD/方向键 + 移动端虚拟摇杆（TouchInput.move_vector）合并驱动。
const SPEED: float = 220.0

@export var max_health: float = 100.0
@export var bullet_scene: PackedScene

var health: float = 100.0
var ammo: int = 20
var is_dead: bool = false
var _last_dir: Vector2 = Vector2.RIGHT

@onready var flashlight: PointLight2D = $Flashlight

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dir += TouchInput.move_vector
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * SPEED
	if dir != Vector2.ZERO:
		_last_dir = dir.normalized()
		flashlight.rotation = dir.angle()
	move_and_slide()

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
	if ammo <= 0 or not bullet_scene:
		return
	ammo -= 1
	Juice.hitstop(0.06, 0.06)
	var b: Area2D = bullet_scene.instantiate()
	b.setup(_last_dir)
	# 从身体边缘生成，避免卡在自身碰撞体里
	b.global_position = global_position + _last_dir * 18.0
	get_tree().current_scene.add_child(b)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	Juice.add_trauma(0.3)
	Juice.hitstop(0.04, 0.05)
	EventBus.player_hit.emit(amount)
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	GameState.end_run()
	set_physics_process(false)
	visible = false
