class_name UpgradePool
extends RefCounted
# 局内三选一升级卡池（§11.11）：数据与效果解耦，卡只改 GameState.mods 的乘区/加区，
# Player / Bullet / Pickup 各自读取重算，谁都不用认识「卡片」这个概念。
# 每张卡有叠加上限，避免单局数值爆炸。
#
# icon 用单个汉字而不是 emoji/几何符号：项目全局字体是 system_cjk.tres，
# 生僻符号在部分中文字体里没有字形会渲染成豆腐块，汉字最稳，也贴合中文标题调性。

const CARDS := [
	{"id": "fire_rate", "name": "疾速孢子", "icon": "速", "color": Color(0.4, 0.9, 1.0),
	 "desc": "射速 +15%\n每级叠加，越打越密"},
	{"id": "damage", "name": "尖刺孢囊", "icon": "锐", "color": Color(1.0, 0.55, 0.4),
	 "desc": "子弹伤害 +20%\n硬碰硬的底气"},
	{"id": "projectiles", "name": "分裂射", "icon": "散", "color": Color(0.7, 0.6, 1.0),
	 "desc": "额外增加 1 条弹道\n散射覆盖更宽"},
	{"id": "move_speed", "name": "轻足", "icon": "轻", "color": Color(0.4, 1.0, 0.75),
	 "desc": "移动速度 +12%\n怪群更容易甩开"},
	{"id": "vitality", "name": "厚壁", "icon": "壁", "color": Color(1.0, 0.45, 0.6),
	 "desc": "最大生命 +25\n并立即回复 25"},
	{"id": "magnet", "name": "引力场", "icon": "引", "color": Color(0.45, 0.85, 1.0),
	 "desc": "晶体磁吸范围 +30%\n不用贴脸捡"},
	{"id": "pierce", "name": "贯穿孢针", "icon": "穿", "color": Color(1.0, 0.8, 0.35),
	 "desc": "子弹额外穿透 1 只怪\n成串打穿怪墙"},
	{"id": "bullet_speed", "name": "疾风孢针", "icon": "迅", "color": Color(0.6, 1.0, 0.9),
	 "desc": "弹速 +25%\n射程同步变长"},
]

const MAX_TAKEN := {
	"fire_rate": 6, "damage": 8, "projectiles": 4, "move_speed": 4,
	"vitality": 6, "magnet": 4, "pierce": 3, "bullet_speed": 4,
}

# 从未达上限的卡里随机抽 n 张不重复的（上限全满时返回空数组，主逻辑自动跳过升级弹窗）
static func pick(taken: Dictionary, n: int = 3) -> Array:
	var pool: Array = []
	for c in CARDS:
		if int(taken.get(c.id, 0)) < int(MAX_TAKEN.get(c.id, 99)):
			pool.append(c)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))

static func by_id(id: String) -> Dictionary:
	for c in CARDS:
		if c.id == id:
			return c
	return {}

static func max_taken(id: String) -> int:
	return int(MAX_TAKEN.get(id, 99))
