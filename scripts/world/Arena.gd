extends Node2D
# 主战场入口：场景就绪即启动无尽循环（§11.4.4）。
# 地面用网格化 Sprite 平铺，规避 TileMap/TileSet 在弱 GPU 上的兼容风险。

@export var ground_texture: Texture2D
@export var ground_tile: float = 512.0
@export var ground_grid: int = 5

func _ready() -> void:
	GameState.start_run()
	_build_ground()

func _build_ground() -> void:
	if not ground_texture:
		return
	var root := Node2D.new()
	root.name = "GroundRoot"
	add_child(root)
	var half: int = ground_grid / 2
	for gx in range(-half, half + 1):
		for gy in range(-half, half + 1):
			var s := Sprite2D.new()
			s.texture = ground_texture
			s.centered = true
			s.position = Vector2(gx, gy) * ground_tile
			s.z_index = -10
			root.add_child(s)
