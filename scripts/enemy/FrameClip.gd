extends Resource
class_name FrameClip
# 一条帧序列（动画剪辑）。
#
# 约定：帧按「帧001、帧002…」逻辑编号，对应 assets/anim/<key>/<clip>/frame_001.png …
# 播放器永远按数组下标升序播放，不排序、不随机、不跳帧。
#
# 模式：
#   loop = true  —— 循环播放（行走/待机），播到末帧回到帧001
#   loop = false —— 单次播放（攻击/受击/破土），播到末帧停在末帧并发出 finished，
#                   由播放器切回循环剪辑
#
# 帧率与总时长：
#   fps 默认 12；总时长 = 帧数 / fps（4 帧即 0.333 秒）。
#   单次剪辑播完即触发切换，因此"总时长"就是一次动作的完整时长。

@export var clip_name: String = ""
@export var frames: Array[Texture2D] = []
@export var fps: float = 12.0
@export var loop: bool = true

func duration() -> float:
	if fps <= 0.0 or frames.is_empty():
		return 0.0
	return float(frames.size()) / fps

func frame_count() -> int:
	return frames.size()

func is_valid() -> bool:
	return not frames.is_empty() and fps > 0.0

func texture_at(index: int) -> Texture2D:
	if frames.is_empty():
		return null
	return frames[clampi(index, 0, frames.size() - 1)]

func last_index() -> int:
	return maxi(0, frames.size() - 1)
