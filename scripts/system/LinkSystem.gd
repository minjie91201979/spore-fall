extends RefCounted
class_name LinkSystem
# Wave 3 链结对管理器（§11.16）。
#
# 职责：维护一对 linker 的 instance_id -> instance_id 映射，
# 提供「注册 / 解除 / 查对家 / 应用分摊」四个原子操作。
# 用 RefCounted 而非 Autoload Node，避免 tree 生命周期绑定；
# Linker 实体在 configure 时主动 register，die 时主动 dissolve。

var _links: Dictionary = {}   # key = instance_id，value = 对家的 instance_id

## 两 linker 互为链结对，返回 true = 成功建立双向链接
func register(id_a: int, id_b: int) -> bool:
	if _links.has(id_a) or _links.has(id_b):
		return false   # 已被其他 linker 占用
	_links[id_a] = id_b
	_links[id_b] = id_a
	return true

## 解除某 linker 的链结对；若它本来就没对家则静默
func dissolve(id: int) -> void:
	if not _links.has(id):
		return
	var partner := _links[id] as int
	_links.erase(id)
	_links.erase(partner)

## 查询某 linker 的对家实例 ID；无对家返回 -1
func get_partner(id: int) -> int:
	return _links.get(id, -1)

## 把 src 受到的 amount 伤害分摊到 partner（若存在）
## 返回 src 实际承受的伤害（扣除分摊部分后）
func apply_sharing(src_id: int, amount: float, stats: Object) -> float:
	var partner_id := _links.get(src_id, -1) as int
	if partner_id == -1 or not is_instance_valid_or_null(partner_id, stats):
		return amount
	# stats 上须有 @export var link_dmg_share_ratio : float = 0.5
	var ratio: float = stats.get("link_dmg_share_ratio", 0.5) if stats is Resource else 0.5
	var share := amount * ratio
	# partner 最多承受自身 max_health 的 20%（防瞬杀），超出仍由 src 吃
	var partner_node := _get_node_by_id(partner_id)
	if partner_node != null and partner_node.has_method("take_damage"):
		var partner_max_hp: float = partner_node.get("max_health") if partner_node.has_method("get") else 999.0
		var capped_share: float = minf(share, partner_max_hp * 0.2)
		partner_node.take_damage(capped_share)
		return amount - capped_share
	return amount

## 实例级有效判断（RefCounted 不能直接 is_instance_valid）
static func is_instance_valid_or_null(id: int, base: Object) -> bool:
	var n := _get_node_by_id(id)
	return n != null and n.is_inside_tree()

static func _get_node_by_id(id: int) -> Node:
	# 安全遍历根节点的 scene 树找匹配 instance_id
	var root := Engine.get_main_loop().root
	if root == null:
		return null
	for child in root.get_children():
		if child.has_meta("__scene_root"):
			return _find_in_branch(child, id)
	return null

static func _find_in_branch(node: Node, id: int) -> Node:
	if node.get_instance_id() == id:
		return node
	for c in node.get_children():
		var found := _find_in_branch(c, id)
		if found != null:
			return found
	return null
