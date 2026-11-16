extends SceneTree
# 冒烟：确认 Wave 3 五个 .tres 与其贴图能被真正 load（不是仅存在于磁盘）。
# 这一层如果掉了，WaveMode.gd 的 const preload 会让整个波次控制器编译失败，
# 表现为「怪物能刷、但 BOSS 永远不出现」。

func _initialize() -> void:
	var targets := {
		"mirror": "res://assets/data/enemy_mirror.tres",
		"falsebloom": "res://assets/data/enemy_falsebloom.tres",
		"linker": "res://assets/data/enemy_linker.tres",
		"wraith": "res://assets/data/enemy_wraith.tres",
		"loomweaver": "res://assets/data/enemy_loomweaver.tres",
	}
	var bad := 0
	for key in targets:
		var path: String = targets[key]
		var st = load(path)
		if st == null:
			print("BAD  ", key, " -> tres load failed")
			bad += 1
			continue
		var tex = st.get("sprite_texture")
		if tex == null:
			print("BAD  ", key, " -> sprite_texture NULL")
			bad += 1
			continue
		print("OK   ", key, " name=", st.get("display_name"),
			" hp=", st.get("max_health"),
			" behavior=", st.get("behavior"),
			" tex=", tex.resource_path)
	print("SMOKE_BAD=", bad)
	quit()
