extends Node2D
# 通用节点对象池（§11.9）：预实例化 + 循环复用，替代高频 instantiate/queue_free。
# 移动端收益：消除生成/销毁节点的 GC 式尖峰，稳住同屏 100+ 的帧率。
#
# ⚠️ 摆位纪律（真 bug 教训）：节点必须「先设 position 再 add_child」。
#    若先入树再摆位，物理服务器会按出生点 (0,0) 注册碰撞体一帧，
#    与玩家重叠触发 move_and_slide 去重叠，把玩家甩进停车场 (100000,100000)
#    —— 表现为「地面消失」（相机跟着玩家飞了）。
#    停车场节点同时清零 collision_layer/mask，杜绝残余碰撞。
#
# 用法：
#   Arena.tscn 里挂两个本脚本节点（BulletPool / EnemyPool），各自导出 pooled_scene + prefill；
#   生成方用组名取池：get_tree().get_first_node_in_group("bullet_pool")，acquire(parent) 拿节点；
#   被池化的对象自己实现 active 开关（false 时不跑逻辑）与 release 流程（见 Bullet.gd / Enemy.gd）。

const PARK_POS := Vector2(100000, 100000)   # 停车场：远离战场，杜绝任何残余交互

@export var pool_group: String = ""          # 挂到的组名，供生成方查找
@export var pooled_scene: PackedScene        # 池化的场景
@export var prefill: int = 0                 # 开局预实例化数量（避免游戏中途实例化尖峰）

var _free_nodes: Array[Node] = []

func _ready() -> void:
	if pool_group != "":
		add_to_group(pool_group)
	for i in prefill:
		var n: Node = pooled_scene.instantiate()
		n.set_meta("pool", self)
		n.set("active", false)
		n.visible = false
		n.position = PARK_POS       # ⚠️ 先摆位再入树（见文件头注释）
		add_child(n)
		_park_collision(n)
		_free_nodes.append(n)

# 从池取一个节点并挂到 parent（通常是 current_scene，保证 y_sort 排序正确）
func acquire(parent: Node) -> Node:
	var n: Node
	if _free_nodes.is_empty():
		n = pooled_scene.instantiate()
		n.set_meta("pool", self)
	else:
		n = _free_nodes.pop_back()
	if n.has_method("reset_for_reuse"):
		n.reset_for_reuse()
	n.set("active", true)
	n.visible = true
	_restore_collision(n)
	if n.get_parent() == null:
		parent.add_child(n)
	elif n.get_parent() != parent:
		n.reparent(parent)
	return n

# 归还节点到池（只允许在非物理回调上下文调用，或经 call_deferred 转入）
func release(n: Node) -> void:
	if n.get_parent() != self:
		n.reparent(self)
	n.set("active", false)
	n.visible = false
	n.position = PARK_POS
	_park_collision(n)
	if not _free_nodes.has(n):
		_free_nodes.append(n)

# ---- 停车场碰撞开关（layer/mask 原值记在 meta 里，取用时还原） ----
func _park_collision(n: Node) -> void:
	if not n.has_meta("col_layer"):
		n.set_meta("col_layer", n.get("collision_layer"))
		n.set_meta("col_mask", n.get("collision_mask"))
	n.set("collision_layer", 0)
	n.set("collision_mask", 0)

func _restore_collision(n: Node) -> void:
	if n.has_meta("col_layer"):
		n.set("collision_layer", n.get_meta("col_layer"))
		n.set("collision_mask", n.get_meta("col_mask"))
