extends SceneTree

const PROBE_PATH := "user://_probe_settings.cfg"
const REAL_PATH := "user://settings.cfg"

func _init() -> void:
	await process_frame
	var settings = root.get_node_or_null("Settings")
	assert(settings != null, "Settings autoload missing")

	# 快照真实 settings.cfg，测完原样还原，不碰玩家实际设置
	var snap := ConfigFile.new()
	var had_real := snap.load(REAL_PATH) == OK
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))

	settings.config_path = PROBE_PATH
	settings.call("_load")
	assert(settings.auto_aim == true, "默认应为开启")
	settings.set_auto_aim(false)
	var cfg := ConfigFile.new()
	assert(cfg.load(PROBE_PATH) == OK, "探针存档未写出")
	assert(cfg.get_value("gameplay", "auto_aim", true) == false, "false 未落盘")
	settings.auto_aim = true
	settings.call("_load")
	assert(settings.auto_aim == false, "重载未恢复 false")
	print("PASS persistence")

	# 画质保存必须保留 gameplay 区
	settings.config_path = REAL_PATH
	settings.call("_save")
	var quality = root.get_node("Quality")
	quality.set_level(quality.level)
	var both := ConfigFile.new()
	assert(both.load(REAL_PATH) == OK)
	assert(both.has_section("video") and both.has_section("gameplay"), "画质保存冲掉了系统设置区")
	print("PASS cross-section")

	# 面板与三个 UI 入口：全部动态 load，避开 -s 模式静态依赖链编译时机问题
	var panel_script = load("res://scripts/ui/SettingsPanel.gd")
	var panel = panel_script.new()
	root.add_child(panel)
	await process_frame
	panel.open()
	assert(panel.visible, "面板未打开")
	var auto_btn = panel.get("_auto_btn")
	assert(auto_btn != null and auto_btn.text != "", "自瞄按钮未初始化")
	panel.close()
	print("PASS panel")

	var title = load("res://scenes/ui/Title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	assert(title.get("settings_btn") != null, "Title 缺设置按钮")
	print("PASS title")

	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	assert(hud.get("settings_button") != null, "HUD 缺设置按钮")
	print("PASS hud")

	var pause = load("res://scripts/ui/StoryPause.gd").new()
	root.add_child(pause)
	await process_frame
	assert(pause.get("_box").get_child_count() >= 5, "暂停菜单缺设置按钮")
	print("PASS pause")

	# 还原真实设置文件
	if had_real:
		snap.save(REAL_PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REAL_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	print("SETTINGS_PROBE_OK")
	quit(0)
