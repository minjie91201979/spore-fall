extends Node2D
class_name Interactable
# 靠近后按 E（或手机「互动」）触发。不进物理层，避免和子弹层搅在一起。

signal interacted

@export var prompt: String = "按 E 调查 / 手机：点「互动」"
@export var radius: float = 64.0
var enabled: bool = true

func _ready() -> void:
	add_to_group("interactable")
