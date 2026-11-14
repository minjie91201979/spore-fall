extends Node
# 系统设置：玩法/手感选项（当前为「攻击自动瞄准」），与画质档共用 user://settings.cfg。
# 各写各的 section；保存前先 load，保证另一区（video）不被覆盖。
# 运行期 Player 每次开火都读 auto_aim，改设置即时生效，无需重开关卡。

signal auto_aim_changed(enabled: bool)

var config_path: String = "user://settings.cfg"
# 默认开启 = 沿用原有手感（自动锁最近敌人）；关闭后朝最后移动方向射击。
var auto_aim: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停界面里也能改
	_load()

func set_auto_aim(v: bool) -> void:
	if auto_aim == v:
		return
	auto_aim = v
	_save()
	auto_aim_changed.emit(v)

func toggle_auto_aim() -> void:
	set_auto_aim(not auto_aim)

# ---------- 持久化 ----------
func _load() -> void:
	auto_aim = true   # 先回默认，文件不存在/被删时不会残留上次的值
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		auto_aim = bool(cfg.get_value("gameplay", "auto_aim", auto_aim))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(config_path)   # 文件不存在时返回错误，但对象仍可 set/save
	cfg.set_value("gameplay", "auto_aim", auto_aim)
	cfg.save(config_path)
