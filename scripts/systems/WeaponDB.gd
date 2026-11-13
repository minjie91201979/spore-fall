class_name WeaponDB
## 武器数据库（纯静态）：每把武器定义弹道行为，Player 发射时读取，Bullet 按弹种表现。
## 数值全部是「乘区」：与 GameState.weapon_level 成长和升级卡 mods 相乘合流，
## 换武器只换手感与机制，不吃掉玩家已经攒出来的成长。
##
## 字段说明：
##   damage_mult   伤害乘区（基于 Player.bullet_damage 基准）
##   interval_mult 射速间隔乘区（越大越慢；喷火枪 0.28 = 高频短喷）
##   pellets       固定弹丸数；0 = 沿用武器等级派生的弹道数（沙漠飞鹰成长线）
##   spread        相邻弹丸夹角（弧度）
##   speed_mult    弹速乘区（基于 Bullet.base_speed）
##   life_mult     射程乘区（子弹寿命即射程）
##   pierce_add    额外穿透层数；laser 的 pierce_all = 无限穿透
##   bullet_kind   standard 普通 / fire 燃烧弹 / flame 火舌 / laser 激光
##   burn_dps / burn_time   命中点燃：对敌人施加燃烧 DoT（刷新制）
##   sfx / sfx_pitch        开火音效与音高偏移

const ORDER: Array[String] = ["deagle", "shotgun", "firerifle", "flamethrower", "laser"]

const DATA: Dictionary = {
	"deagle": {
		"name": "沙漠飞鹰",
		"icon": "res://assets/ui/wpn_deagle.png",
		"damage_mult": 1.0, "interval_mult": 1.0,
		"pellets": 0, "spread": 0.16,
		"speed_mult": 1.0, "life_mult": 1.0, "pierce_add": 0,
		"bullet_kind": "standard",
		"burn_dps": 0.0, "burn_time": 0.0,
		"sfx": "shoot", "sfx_pitch": 1.0,
	},
	"shotgun": {
		"name": "孢壳霰弹",
		"icon": "res://assets/ui/wpn_shotgun.png",
		"damage_mult": 0.42, "interval_mult": 2.9,
		"pellets": 6, "spread": 0.14,
		"speed_mult": 1.0, "life_mult": 0.62, "pierce_add": 0,
		"bullet_kind": "standard",
		"burn_dps": 0.0, "burn_time": 0.0,
		"sfx": "shotgun", "sfx_pitch": 1.0,
	},
	"firerifle": {
		"name": "火弹枪",
		"icon": "res://assets/ui/wpn_firerifle.png",
		"damage_mult": 0.85, "interval_mult": 0.82,
		"pellets": 0, "spread": 0.10,
		"speed_mult": 1.15, "life_mult": 1.0, "pierce_add": 0,
		"bullet_kind": "fire",
		"burn_dps": 6.0, "burn_time": 2.5,
		"sfx": "shoot", "sfx_pitch": 1.35,
	},
	"flamethrower": {
		"name": "喷火枪",
		"icon": "res://assets/ui/wpn_flamethrower.png",
		"damage_mult": 0.30, "interval_mult": 0.28,
		"pellets": 1, "spread": 0.18,
		"speed_mult": 0.62, "life_mult": 0.30, "pierce_add": 2,
		"bullet_kind": "flame",
		"burn_dps": 9.0, "burn_time": 2.0,
		"sfx": "flame", "sfx_pitch": 1.0,
	},
	"laser": {
		"name": "激光枪",
		"icon": "res://assets/ui/wpn_laser.png",
		"damage_mult": 0.72, "interval_mult": 1.35,
		"pellets": 0, "spread": 0.0,
		"speed_mult": 2.1, "life_mult": 1.1, "pierce_add": 0,
		"pierce_all": true,
		"bullet_kind": "laser",
		"burn_dps": 0.0, "burn_time": 0.0,
		"sfx": "laser", "sfx_pitch": 1.0,
	},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, DATA["deagle"])

static func name_of(id: String) -> String:
	return String(get_def(id).get("name", id))

static func icon_of(id: String) -> Texture2D:
	return load(String(get_def(id).get("icon", "")))

# 随机挑一把「尚未拥有」的武器；全收集后返回空串（掉落方改掉晶体）
static func random_unowned(owned: Array) -> String:
	var pool: Array[String] = []
	for id in ORDER:
		if not owned.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
