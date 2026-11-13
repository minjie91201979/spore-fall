extends Node
# 爽刷打击感工具类（§11.4.5）：hitstop 微停顿 + 屏幕震动 trauma。
# 作为 Autoload（见 project.godot），全局可调用 Juice.hitstop() / Juice.add_trauma()。

var trauma: float = 0.0

# 击杀/受击时短暂放慢时间，制造顿挫感
# 注意：恢复计时必须走真实时间（ignore_time_scale=true），否则减速期间
# 计时器本身也被拖慢 25 倍，0.05s 的顿挫会被锁成 1.25s 的幻灯片
func hitstop(time_scale: float = 0.05, duration: float = 0.08) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

# 累加震动能量，CameraShake 读取后做衰减
func add_trauma(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)

# 移动端触觉反馈（桌面端自动跳过）：受击轻震、死亡/Boss 登场重震
func haptic(duration_ms: int = 30) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func _process(delta: float) -> void:
	trauma = max(trauma - delta * 1.2, 0.0)
