extends Node
# 资源管理：弹药 / 草药 / 血清（§4.2 / §11.4.4）。
# 单局有限背包，制造「以战养战」的稀缺张力。切片阶段由拾取物调用 add()。

var ammo: int = 20
var herbs: int = 4
var serum: int = 0

func add(type: String, amount: int) -> void:
	match type:
		"ammo":
			ammo += amount
		"herb":
			herbs += amount
		"serum":
			serum += amount
	EventBus.pickup_collected.emit(type, amount)
