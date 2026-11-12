extends Node
# 画质档位（§11.6）：低 / 中 / 高三档，实时切换 + user:// 持久化。
# 只调三个**真实有开销**的开关，不做假选项：
#   1) 描边 pass —— 每个实体多一次 Sprite 绘制（外扩描边图，见 shaders/outline.gdshader）
#   2) GPUParticles2D 数量比例 —— 同屏爆裂粒子的填充率，低端机 GPU 的主要瓶颈
#   3) 动态光强度/半径 —— 手电锥光的 overdraw
# 注册制：实体在 _ready 里注册自己，切档时遍历组统一改；池化复用不必重复注册，
# 但每次 acquire 复用后仍会走 _apply_visual，可见性由组内状态统一控制。

const CONFIG_PATH := "user://settings.cfg"
const LEVEL_NAMES := ["低", "中", "高"]

enum Level { LOW, MEDIUM, HIGH }

var level: int = Level.HIGH

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 死亡慢动作时也要能切档
	_load_saved()

# ---------- 实体注册 ----------
func register_outline(layer: CanvasItem) -> void:
	layer.add_to_group("outline_sprite")
	layer.visible = outline_enabled()

func register_particles(p: GPUParticles2D) -> void:
	p.add_to_group("kill_particles")
	p.set("amount_ratio", particle_ratio())

func register_light(l: PointLight2D) -> void:
	l.add_to_group("dyn_light")
	_apply_light(l)

# ---------- 档位参数 ----------
func outline_enabled() -> bool:
	return level >= Level.MEDIUM

func particle_ratio() -> float:
	match level:
		Level.LOW:
			return 0.35
		Level.MEDIUM:
			return 0.7
	return 1.0

func light_energy() -> float:
	match level:
		Level.LOW:
			return 1.15
		Level.MEDIUM:
			return 1.5
	return 1.8

func light_scale() -> float:
	match level:
		Level.LOW:
			return 3.6
		Level.MEDIUM:
			return 4.4
	return 5.0

# ---------- 切档 ----------
func cycle() -> void:
	set_level((level + 1) % 3)

func set_level(v: int) -> void:
	level = clampi(v, 0, 2)
	apply_all()
	_save()
	EventBus.quality_changed.emit(level)

func apply_all() -> void:
	for s in get_tree().get_nodes_in_group("outline_sprite"):
		if is_instance_valid(s):
			s.visible = outline_enabled()
	var pr := particle_ratio()
	for p in get_tree().get_nodes_in_group("kill_particles"):
		if is_instance_valid(p):
			p.set("amount_ratio", pr)
	for l in get_tree().get_nodes_in_group("dyn_light"):
		if is_instance_valid(l):
			_apply_light(l)

func _apply_light(l: PointLight2D) -> void:
	l.energy = light_energy()
	l.scale = Vector2.ONE * light_scale()

# ---------- 持久化 ----------
func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		level = clampi(int(cfg.get_value("video", "quality", level)), 0, 2)
		return
	# 首次启动：手机默认中档（保 60fps 下限），桌面默认高档
	level = Level.MEDIUM if OS.has_feature("mobile") else Level.HIGH

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", level)
	cfg.save(CONFIG_PATH)
