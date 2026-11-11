extends SceneTree
func _init() -> void:
	var ok := true
	for p in ["res://assets/data/enemy_walker.tres", "res://assets/data/enemy_runner.tres", "res://assets/data/enemy_brute.tres"]:
		var s: Resource = load(p)
		if s == null:
			print("FAIL load: ", p)
			ok = false
			continue
		print("OK %s | %s speed=%.0f hp=%.0f atk=%.0f tint=%s scale=%.2f w0=%.2f wpt=%.2f" % [
			p.get_file(), s.display_name, s.move_speed, s.max_health, s.attack_power,
			s.tint, s.scale_mult, s.spawn_weight_tier0, s.spawn_weight_per_tier])
	print("STATS-CHECK ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
