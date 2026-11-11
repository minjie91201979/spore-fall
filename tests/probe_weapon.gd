extends Node
# 临时探针：武器升级链路——晶体累积 → 升级 → 数值刷新 → 多弹道开火
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var player: Node = get_tree().get_first_node_in_group("player")
	print("PROBE lv=%d interval=%.3f dmg=%.1f proj=%d" % [
		GameState.weapon_level, player.fire_interval, player.bullet_damage, player.projectile_count])
	# 拾 3 颗晶体 → 升 LV2
	for i in 3:
		GameState.add_crystal()
	await get_tree().process_frame
	print("PROBE after3crystals lv=%d crystals=%d interval=%.3f dmg=%.1f proj=%d" % [
		GameState.weapon_level, GameState.crystals, player.fire_interval, player.bullet_damage, player.projectile_count])
	# 再拾 4 颗 → 升 LV3（应解锁 2 弹道）
	for i in 4:
		GameState.add_crystal()
	await get_tree().process_frame
	print("PROBE after7crystals lv=%d proj=%d" % [GameState.weapon_level, player.projectile_count])
	# 开火一发，数子弹（LV3 = 2 弹道）
	var before: int = _active_bullets()
	player.fire()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var after: int = _active_bullets()
	print("PROBE fired bullets %d -> %d (expect +2)" % [before, after])
	var ok: bool = GameState.weapon_level == 3 and player.projectile_count == 2 and (after - before) == 2
	print("PROBE %s" % ("PASS" if ok else "FAIL"))
	get_viewport().get_texture().get_image().save_png("C:/Users/musou/Desktop/object/spore-fall/build/weapon_probe.png")
	get_tree().quit(0 if ok else 1)

func _active_bullets() -> int:
	var n := 0
	for b in get_tree().current_scene.get_children():
		if b is Area2D and b.get("active") and b.active:
			n += 1
	return n
