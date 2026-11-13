extends Node
# 全局音效播放器（Autoload: Sfx）：8 路 AudioStreamPlayer 轮播，
# 同名音效连发不互掐；bgm 单独一路循环。
# 用法：Sfx.play("shoot") / Sfx.play("hit") ...

const STREAMS := {
	"shoot": preload("res://assets/audio/shoot.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"kill": preload("res://assets/audio/kill.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"pickup": preload("res://assets/audio/pickup.wav"),
	"levelup": preload("res://assets/audio/levelup.wav"),
	"spit": preload("res://assets/audio/spit.wav"),
	"shotgun": preload("res://assets/audio/shotgun.wav"),
	"laser": preload("res://assets/audio/laser.wav"),
	"flame": preload("res://assets/audio/flame.wav"),
	"amb_boss": preload("res://assets/audio/amb_boss.wav"),
	"amb_forest": preload("res://assets/audio/amb_forest.wav"),
	"amb_hvac": preload("res://assets/audio/amb_hvac.wav"),
}
# 各音效音量（dB），开火最轻避免刷屏刺耳
const VOLUMES := {
	"shoot": -16.0,
	"hit": -8.0,
	"kill": -6.0,
	"hurt": -6.0,
	"pickup": -8.0,
	"levelup": -5.0,
	"spit": -10.0,
	"shotgun": -7.0,
	"laser": -9.0,
	"flame": -12.0,
	"amb_boss": -20.0,
	"amb_forest": -26.0,
	"amb_hvac": -24.0,
}
const VOICES := 8

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _bgm: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # hitstop 减速时音效照常
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_bgm = AudioStreamPlayer.new()
	add_child(_bgm)
	_bgm.stream = preload("res://assets/audio/bgm_loop.wav")
	_bgm.volume_db = -14.0
	_bgm.finished.connect(_on_bgm_finished)

func play(sound_name: String, pitch: float = 1.0, volume_offset: float = 0.0) -> void:
	if not STREAMS.has(sound_name):
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = STREAMS[sound_name]
	p.volume_db = VOLUMES.get(sound_name, -8.0) + volume_offset
	p.pitch_scale = pitch
	p.play()

func start_bgm() -> void:
	# 剧情会把循环压低，回到生存时恢复原来的音量
	_bgm.volume_db = -14.0
	if not _bgm.playing:
		_bgm.play()

func set_bgm_db(db: float) -> void:
	_bgm.volume_db = db

func stop_bgm() -> void:
	_bgm.stop()


const AMBIENT_VOICES := 3
var _ambient_streamers: Array[AudioStreamPlayer] = []
var _ambient_idx: int = 0

func start_ambient(name: String) -> void:
	if not STREAMS.has(name):
		return
	var p := _pick_ambient()
	var s: AudioStream = STREAMS[name]
	p.stream = s
	p.volume_db = VOLUMES.get(name, -20.0)
	p.play(0.0)

func stop_all_ambient() -> void:
	for p in _ambient_streamers:
		p.stop()

func _pick_ambient() -> AudioStreamPlayer:
	if _ambient_streamers.is_empty():
		for i in AMBIENT_VOICES:
			var a := AudioStreamPlayer.new()
			add_child(a)
			_ambient_streamers.append(a)
	var p := _ambient_streamers[_ambient_idx]
	_ambient_idx = (_ambient_idx + 1) % len(_ambient_streamers)
	return p

func _on_bgm_finished() -> void:
	_bgm.play()   # wav 循环兜底（import 未设 loop 时手动续播）
