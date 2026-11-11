extends Node2D
# 主战场入口：场景就绪即启动无尽循环（§11.4.4）。
# 地面用网格化 Sprite 平铺，规避 TileMap/TileSet 在弱 GPU 上的兼容风险。

@export var ground_texture: Texture2D
@export var ground_tile: float = 512.0
@export var ground_grid: int = 5
@export var obstacle_count: int = 8

const OBSTACLE_SCENE := preload("res://scenes/world/Obstacle.tscn")

func _ready() -> void:
	GameState.start_run()
	Sfx.start_bgm()
	_build_ground()
	_spawn_obstacles()

# 随机撒障碍柱：避开玩家出生圈（260px），柱间最小间距 260px，
# 保证任一柱子都可以从两侧绕过。先摆位再入树（池化教训同款）。
func _spawn_obstacles() -> void:
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < obstacle_count and attempts < 300:
		attempts += 1
		var p := Vector2(randf_range(-900.0, 900.0), randf_range(-900.0, 900.0))
		if p.length() < 260.0:
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 260.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
	for p in placed:
		var o: Node2D = OBSTACLE_SCENE.instantiate()
		o.position = p
		o.rotation = randf() * TAU
		o.scale = Vector2.ONE * randf_range(0.85, 1.3)
		add_child(o)

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
