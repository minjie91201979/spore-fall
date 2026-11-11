extends Node
# 爽刷打击感工具类（§11.4.5）：hitstop 微停顿 + 屏幕震动 trauma。
# 作为 Autoload（见 project.godot），全局可调用 Juice.hitstop() / Juice.add_trauma()。

var trauma: float = 0.0

# 击杀/受击时短暂放慢时间，制造顿挫感
func hitstop(time_scale: float = 0.05, duration: float = 0.08) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration).timeout
	Engine.time_scale = 1.0

# 累加震动能量，CameraShake 读取后做衰减
func add_trauma(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)

func _process(delta: float) -> void:
	trauma = max(trauma - delta * 1.2, 0.0)
