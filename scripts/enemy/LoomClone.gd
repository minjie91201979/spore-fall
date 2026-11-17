extends CharacterBody2D
# §Wave3 P2 织理者「克隆降临」生成的镜影孢幻影。
# 设计契约（docs/wave3-boss-state-machine.md）：
#   - 受击不扣血，只播攻击特效（给玩家「打不动」的即时反馈）
#   - 2s 后自毁，并在消失点各生成一颗伪晶体
#   - 不能加入 "boss" 组，避免抢 BossBar / 击杀计数
#
# ⚠️ 池化教训（B1 修复）：本脚本由 Boss 生成时独立 instantiate Enemy.tscn 再 set_script，
#    **绝不**从 enemy_pool.acquire() 取节点改脚本——改过的脚本不会随 release 还原，
#    下次刷怪 configure() 会打到本脚本导致整条刷怪链崩坏（同 Wave3 坏 PNG 的连锁故障）。
#    因此幻影用完直接 queue_free，不归还对象池；每次降临 2~3 只，无实例化尖峰风险。

var _owner: Node2D
var _life: float = 2.0
var _base_tint: Color = Color(0.55, 0.75, 1.0, 1.0)
var _elapsed: float = 0.0
var active: bool = true

const FALSE_PICKUP_SCENE := preload("res://scenes/world/Pickup.tscn")

func configure_clone(src_stats: EnemyStats, owner_node: Node2D) -> void:
	_owner = owner_node
	_life = 2.0
	_elapsed = 0.0
	active = true
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	var outline: Sprite2D = get_node_or_null("Outline") as Sprite2D
	if spr:
		# 幻影用镜影孢贴图（若存在），否则沿用默认；染色为电蓝半透明
		var tex: Texture2D = load("res://assets/characters/enemy_mirror.png") as Texture2D
		if tex:
			spr.texture = tex
		spr.modulate = _base_tint
		spr.scale = Vector2.ONE * 0.55
	if outline:
		outline.modulate = Color(0.4, 0.7, 1.0, 0.6)
		outline.scale = Vector2.ONE * 0.55
	# 关掉碰撞与导航查询：幻影不追击、不伤人
	var nav: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if nav:
		nav.set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_life -= delta
	# 闪烁提示即将自毁（末 0.6s 加速闪）
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if spr:
		var blink_hz: float = 8.0 if _life > 0.6 else 20.0
		spr.modulate.a = 0.55 + 0.35 * sin(_elapsed * blink_hz)
	if _life <= 0.0:
		_dissolve()

## 受击：只播特效，绝不扣血/计分/发死亡事件
func take_damage(_amount: float) -> void:
	if not active:
		return
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if spr:
		var tw := create_tween()
		tw.tween_property(spr, "modulate", Color.WHITE, 0.06)
		tw.tween_property(spr, "modulate", _base_tint, 0.12)
	Sfx.play("hit", 0.5, 2.0)

func _dissolve() -> void:
	active = false
	_spawn_false_crystal(global_position)
	# 独立节点（非池化）：直接释放。切勿归还 enemy_pool，否则本脚本会污染后续杂兵。
	queue_free()

func _spawn_false_crystal(pos: Vector2) -> void:
	var pk: Node2D = FALSE_PICKUP_SCENE.instantiate()
	pk.kind = "false"
	pk.fake_hp_penalty = 28.0   # 与伪孢孢同档惩罚，诱饵一致
	pk.position = pos            # 先摆位再入树（对象池文件头教训）
	get_tree().current_scene.add_child(pk)
