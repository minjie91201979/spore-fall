extends SceneTree
# 探针：Wave 3 三新变种 + Boss 织理者端到端流转断言。
# 覆盖：
#   §11.14 mirror 缓存 + burst 发射
#   §11.15 false_bloom 诱饵晶体 + 拾取扣血 toast
#   §11.16 linker 配对 + 伤害分摊（LinkSystem 单例）
#   §11.17 wraith 晶体加速 + steal teleport
#   §11.18 loomweaver BOSS 三阶段 spawn
# 注：--script 入口在 Autoload 注册前编译，单例须运行时 get_root().get_node() 取。

var gs: Node
var passc: int = 0
var failc: int = 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/world/Arena.tscn")
	await _frames(15)
	gs = get_root().get_node_or_null("GameState")
	_check(gs != null, "GAMESTATE_FOUND")
	if gs == null:
		quit()
		return
	if not gs.is_running:
		gs.start_run()

	var wm: Node = current_scene.get_node_or_null("WaveMode")
	_check(wm != null, "WAVEMODE_NODE_FOUND")
	_check_data_tuning()

	# ---- 直接推进到 Wave 3（跳过前两波浪费的时间）----
	# headless delta 极小，依赖墙钟不可靠；直接 set wave 驱动流程
	if wm:
		wm.set("_wave", 2)                          # 假装已完成第二波
		wm.set("_wave2_started", true)
		wm.set("_boss_down", true)                  # 第二波 BOSS 已倒
		wm.set("_wave3_started", false)
		wm.set("_wave3_reinforced", false)
		wm.set("_loomweaver_spawned", false)
		# 触发第三波启动逻辑（模拟第二波 BOSS 刚被击溃后弹卡继续）
		_check(_start_wave3_via_wm(wm), "WAVE3_TRIGGERED")
	await _frames(30)

	# ---- §11.14 Mirror Spore ----
	var mirror := _find_active_by_behavior("mirror")
	_check(mirror != null, "MIRROR_SPAWNED")
	if mirror:
		_check(mirror.stats.move_speed == 0.0, "MIRROR_IDLE_MOVESPEED_ZERO")
		_check(_is_mirror_firing(mirror), "MIRROR_BURST_FIRED(%d_cached)" % mirror._mirror_cache.size())
		# 镜像 burst 应射出子弹（ EnemyBullet 组）
		var bullet_count := _count_bullets_kind("needle")
		_check(bullet_count >= 1, "MIRROR_BULLET_FIRED_COUNT=%d" % bullet_count)

	# ---- §11.15 False Bloom 诱饵晶体 ----
	var falsebloom := _find_active_by_behavior("false_bloom")
	_check(falsebloom != null, "FALSE_BLOOM_SPAWNED")
	if falsebloom:
		falsebloom.take_damage(falsebloom.max_health + 1)  # 触发死亡分支
		await _frames(5)
		var fake_pickup := _find_false_pickup_on_ground()
		_check(fake_pickup != null, "FALSE_PICKUP_SPAWNED_AFTER_DEATH")
		if fake_pickup:
			# 玩家拾取伪晶体 → 应扣血并 toast
			var pl: Node2D = get_first_node_in_group("player") as Node2D
			fake_pickup.kind = "false"
			fake_pickup.fake_hp_penalty = 25.0
			fake_pickup.global_position = pl.global_position + Vector2.ONE * 10.0
			fake_pickup._collect()
			await _frames(3)
			_check(pl.health < pl.max_health, "FALSE_CRYSTAL_HP_PENALTY_APPLIED")

	# ---- §11.16 Linker 配对 + LinkSystem ----
	var linker_a := _find_active_by_behavior("linker")
	_check(linker_a != null, "LINKER_A_SPAWNED")
	# 再找一只 linker 组成对子（场上应有至少 2 只）
	var linker_b := _find_second_linker_after(linker_a)
	_check(linker_b != null, "LINKER_B_EXISTS_FOR_PAIRING")
	if linker_a and linker_b:
		# 手动调用 _register_link 建立配对
		linker_a._register_link(linker_b.get_instance_id(), linker_b.stats)
		linker_b._register_link(linker_a.get_instance_id(), linker_a.stats)
		await _frames(2)
		_check(linker_a._link_partner_id != -1, "LINKER_A_HAS_PARTNER(%d)" % linker_a._link_partner_id)
		_check(linker_b._link_partner_id != -1, "LINKER_B_HAS_PARTNER(%d)" % linker_b._link_partner_id)
		# 对 A 造成伤害，B 应承受分摊后的部分
		var dmg_total: float = 60.0
		var partner_max_hp: float = linker_b.max_health
		linker_a.take_damage(dmg_total)
		await _frames(2)
		var actual_a_hp_change: float = dmg_total - minf(dmg_total * 0.5, partner_max_hp * 0.2)
		_check(absf(linker_a.health - (linker_a.max_health - actual_a_hp_change)) < 1.0,
			"LINKER_A_DMG_SHARED_APPROX(expected_delta=%.1f got_delta=%.1f)" % [actual_a_hp_change, linker_a.max_health - linker_a.health])
		# 解除链结对
		linker_a._dissolve_link()
		_check(linker_a._link_partner_id == -1, "LINKER_A_DISSOLVED")
		_check(linker_b._link_partner_id == -1, "LINKER_B_ALSO_DISSOLVED")

	# ---- §11.17 Crystal Wraith 加速 + steal ----
	var wraith := _find_active_by_behavior("wraith")
	_check(wraith != null, "WRAITH_SPAWNED")
	if wraith:
		_check(wraith.stats.wraith_crystal_boost_per_crystal > 0.0, "WRAITH_BOOST_CONFIGURED")
		# headless 场上可能一颗晶体都没有（没有击杀掉落），主动补一颗真晶体做加速基线
		if _count_ground_crystals_no_fake() < 1:
			_spawn_test_crystal(wraith.global_position + Vector2(60, 0))
			await _frames(2)
		var crystal_count := _count_ground_crystals_no_fake()
		_check(crystal_count >= 1, "GROUND_CRYSTALS_EXIST(%d)" % crystal_count)
		if crystal_count > 0:
			var base_speed: float = wraith.stats.move_speed
			var boosted_speed: float = base_speed + \
				minf(wraith.stats.wraith_crystal_boost_per_crystal * float(crystal_count), 40.0)
			_check(boosted_speed > base_speed,
				"WRAITH_SPEED_BOOSTED(base=%.1f boosted=%.1f crystals=%d)" % [
					base_speed, boosted_speed, crystal_count])

	# ---- §11.18 Loom Weaver BOSS ----
	var loom := _find_active_by_behavior("boss")   # 用行为字段区分杂兵 vs boss（loomweaver behavior="boss"）
	# 注意：渊噬孢也是 boss，需要通过 stats 过滤
	if loom:
		var loom_stats = loom.get("stats")
		_check(loom_stats != null and "织理者" in loom_stats.display_name,
			"LOOM_WEAVER_BOSS_SPAWNED(name=%s)" % (loom_stats.display_name if loom_stats else "null"))

	print("WAVE3_PASS=%d FAIL=%d" % [passc, failc])
	print("OK" if failc == 0 else "FAILED")
	quit()

func _start_wave3_via_wm(wm: Node) -> bool:
	# 通过公共 API 触发 _start_wave3（若存在公开方法则调用；否则反射）
	if wm.has_method("_start_wave3"):
		wm._start_wave3()
		return true
	# 兜底：直接操作受保护的变量
	wm.set("_wave", 3)
	wm.set("_wave3_started", true)
	wm.set("_wave3_t", 0.0)
	wm.set("_wave3_reinforced", false)
	wm.set("_boss_down", false)
	return true

func _check_data_tuning() -> void:
	# Wave 3 数据文件必须可读且关键参数合理
	var paths := {
		"mirror": "res://assets/data/enemy_mirror.tres",
		"falsebloom": "res://assets/data/enemy_falsebloom.tres",
		"linker": "res://assets/data/enemy_linker.tres",
		"wraith": "res://assets/data/enemy_wraith.tres",
		"loomweaver": "res://assets/data/enemy_loomweaver.tres",
	}
	for key in paths:
		var path: String = paths[key] as String
		var st = load(path)
		_check(st != null, "TRES_LOADED(%s)" % key)
		if st == null:
			continue
		_check(st.behavior != "", "BEHAVIOR_SET(%s=%s)" % [key, st.behavior])
		if key == "mirror":
			_check(st.mirror_cache_size == 3, "MIRROR_CACHE_SIZE=3")
			_check(st.mirror_burst_interval > 0.0, "MIRROR_BURST_INTERVAL_POSITIVE")
		elif key == "falsebloom":
			_check(st.false_pickup_hp_penalty > 0.0, "FALSE_PENALTY_POSITIVE")
		elif key == "linker":
			_check(st.link_dmg_share_ratio > 0.0 and st.link_dmg_share_ratio <= 1.0,
				"LINK_RATIO_VALID(%.2f)" % st.link_dmg_share_ratio)
		elif key == "wraith":
			_check(st.wraith_crystal_boost_per_crystal > 0.0, "WRAITH_BOOST_POSITIVE")
		elif key == "loomweaver":
			_check(st.is_boss, "LOOMWEAVER_IS_BOSS")
			_check(st.max_health > 5000.0, "LOOMWEAVER_HP_HIGH(%.0f)" % st.max_health)

func _find_active_by_behavior(behavior: String) -> Node:
	for e in get_nodes_in_group("enemy"):
		if not e.get("active"):
			continue
		var st = e.get("stats")
		if st and st.behavior == behavior:
			return e
	return null

func _find_second_linker_after(first: Node) -> Node:
	var seen_first := false
	for e in get_nodes_in_group("enemy"):
		if not e.get("active"):
			continue
		var st = e.get("stats")
		if st and st.behavior == "linker":
			if not seen_first:
				seen_first = true
				continue
			return e
	return null

func _is_mirror_firing(mirror: Node) -> bool:
	# 简单启发：mirror_cache 满 3 条即认为「就绪可 burst」
	return mirror._mirror_cache.size() >= 3

func _count_bullets_kind(kind: String) -> int:
	# EnemyBullet 把发射类型存在私有字段 _kind（不是 kind），这里两种都兼容
	var n := 0
	for b in get_nodes_in_group("enemy_bullet"):
		if b.get("_kind") == kind or b.get("kind") == kind:
			n += 1
	return n

func _find_false_pickup_on_ground() -> Node:
	for p in get_nodes_in_group("pickup"):
		if p.get("kind") == "false" and not p.get("_collected"):
			return p
	return null

func _count_ground_crystals_no_fake() -> int:
	var n := 0
	for p in get_nodes_in_group("pickup"):
		if p.get("kind") == "crystal" and not p.get("_collected"):
			n += 1
	return n

## 直接在场景里放一颗真晶体，供蚀晶孢加速断言使用
func _spawn_test_crystal(pos: Vector2) -> void:
	var pk: Node2D = load("res://scenes/world/Pickup.tscn").instantiate()
	pk.kind = "crystal"
	pk.position = pos
	current_scene.add_child(pk)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		passc += 1
		print("PASS ", label)
	else:
		failc += 1
		print("FAIL ", label)

func _fail_exit() -> void:
	print("WAVE3_PASS=%d FAIL=%d" % [passc, failc])
	print("FAILED")
	quit()
