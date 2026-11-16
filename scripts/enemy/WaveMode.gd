extends Node2D
# 波次控制器：取代 Spawner 的计时精英机制，把一局拆成「铺垫 → 一波 BOSS → 过渡卡 → 二波 → 第三波」。
#
# 节奏（秒，均为可导出参数，方便策划调）：
#   0           开局：常规刷怪，玩家攒武器/晶体（wave1_delay 之前的铺垫期）
#   wave1_delay 第一波 BOSS 母巢孢登场
#   击溃        暂停 + 弹 WaveCard「第二波 · 深巢反扑」
#   继续        立刻刷一批新怪（近身半径，保证进视野）→ 进入第二波
#   +reinforce  第二波中途再补一批，避免清完场后干等
#   +wave2_delay 渊噬孢登场
#   击溃        目标改为「区域已肃清 · 进入第三波」
#   wave3_reinforce  第三波中期补怪（镜影孢 + 链结孢各 1-2 只）
#   +wave3_delay 织理者登场（比第二波晚约 30s）
#   击溃        目标改为「区域已肃清 · 第三波通关」
#
# Wave 3 特性：
#   - §11.14 镜影孢 mirror：站桩记录玩家移动方向，缓存满 3 条则射出反射弹
#   - §11.15 伪孢孢 false_bloom：死亡掉落诱饵晶体，拾取扣血 + toast「腐化结晶」
#   - §11.16 链结孢 linker：两两配对，互相分摊 50% 伤害（LinkSystem 全局单例）
#   - §11.17 蚀晶孢 wraith：速度随场上晶体数加速，定期偷取最近一颗晶体 teleport
#   - §11.18 Boss 织理者 loomweaver：三阶段状态机（P1 基础技能 → P2 分裂克隆 → P3 覆写冻结拾取）
#
# 数据流：复用 EnemyPool.acquire + Enemy.configure，与 Spawner.spawn_boss 同构；
# 通过 EventBus.boss_defeated 串联多波，GameState.boss_active 作为全局单 Boss 互斥锁。

const BROOD := preload("res://assets/data/enemy_boss.tres")
const CORRODER := preload("res://assets/data/enemy_corroder.tres")
const BURROWER := preload("res://assets/data/enemy_burrower.tres")
const BLOOM := preload("res://assets/data/enemy_bloom.tres")
const ABYSS := preload("res://assets/data/enemy_abyss.tres")
# Wave 3 新变种（§11.14–17）
const MIRROR := preload("res://assets/data/enemy_mirror.tres")
const FALSE_BLOOM := preload("res://assets/data/enemy_falsebloom.tres")
const LINKER := preload("res://assets/data/enemy_linker.tres")
const WRAITH := preload("res://assets/data/enemy_wraith.tres")
const LOOM_WEAVER := preload("res://assets/data/enemy_loomweaver.tres")

@export var wave1_delay: float = 45.0        # 开局铺垫期：先让玩家捡到武器再上 BOSS
@export var wave2_delay: float = 14.0        # 第二波开始到渊噬孢登场的间隔
@export var reinforce_at: float = 6.0        # 第二波中途补怪时刻（相对第二波开始）
@export var boss_spawn_radius: float = 460.0 # Boss 在玩家周围的登场距离
@export var wave2_spawn_min: float = 240.0  # 第二波开场怪内圈（进视野，不再刷在屏外）
@export var wave2_spawn_max: float = 400.0
# Wave 3 专属节奏参数
@export var wave3_reinforce_at: float = 8.0 # 第三波中期补怪时刻（相对第三波开始）
@export var wave3_delay: float = 35.0       # 第三波开始到织理者登场的时间
@export var wave3_spawn_min: float = 220.0  # 第三波开场怪内圈
@export var wave3_spawn_max: float = 380.0

var _wave: int = 0
var _boss_down: bool = false
var _wave1_t: float = 0.0
var _last_warmup_sec: int = -1
var _wave2_started: bool = false
var _wave2_t: float = 0.0
var _reinforced: bool = false
var _player: Node2D
var _card: CanvasLayer
# Wave 3 状态
var _wave3_started: bool = false
var _wave3_t: float = 0.0
var _wave3_reinforced: bool = false
var _loomweaver_spawned: bool = false

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	EventBus.boss_defeated.connect(_on_boss_defeated)
	GameState.boss_active = false

func _process(delta: float) -> void:
	if not GameState.is_running:
		return
	# 铺垫期：只累计时间，Spawner 常规刷怪给玩家攒资源；到点才上第一波 BOSS。
	# 目标文案必须在这里写而不是 _ready()：Godot 的 _ready 是子节点先于父节点，
	# Arena._ready() 里的 GameState.start_run() 会把 objective_text 清空，覆盖掉 _ready 里设的值。
	# 每秒才改一次字符串，避免每帧刷新 Label。
	if _wave == 0:
		_wave1_t += delta
		var left: int = maxi(0, int(ceil(wave1_delay - _wave1_t)))
		if left != _last_warmup_sec:
			_last_warmup_sec = left
			GameState.objective_text = "目标　清剿孢群 · 母巢孢 %ds 后苏醒" % left
		if _wave1_t >= wave1_delay:
			_start_wave1()
		return
	if _wave2_started and not _boss_down:
		_wave2_t += delta
		if not _reinforced and _wave2_t >= reinforce_at:
			_reinforced = true
			_wave2_reinforce()
		if _wave2_t >= wave2_delay and not _loomweaver_spawned:
			_spawn_boss(ABYSS, 1.0)
			_loomweaver_spawned = true
	if _wave3_started and not _boss_down:
		_wave3_t += delta
		if not _wave3_reinforced and _wave3_t >= wave3_reinforce_at:
			_wave3_reinforced = true
			_wave3_reinforce()
		if _wave3_t >= wave3_delay:
			_spawn_boss(LOOM_WEAVER, 1.0)

func _start_wave1() -> void:
	_wave = 1
	GameState.objective_text = "目标　击溃母巢孢 · 第一波"
	_spawn_boss(BROOD, 1.0)

func _spawn_boss(stats: EnemyStats, hp_mult: float) -> void:
	if GameState.boss_active or not _player or not is_instance_valid(_player):
		return
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	var e: Node2D
	if pool:
		e = pool.acquire(get_tree().current_scene) as Node2D
	else:
		var scn := load("res://scenes/world/Enemy.tscn")
		e = scn.instantiate()
		get_tree().current_scene.add_child(e)
	if e == null or not e.has_method("configure"):
		return
	e.configure(stats, hp_mult)
	var angle: float = randf() * TAU
	e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * boss_spawn_radius
	GameState.boss_active = true
	GameState.bosses_spawned += 1
	EventBus.boss_spawned.emit(stats.display_name, e.get("max_health"))
	Juice.add_trauma(0.6)
	Juice.haptic(120)
	Sfx.play("hurt", 0.4, 5.0)

func _on_boss_defeated(_name: String) -> void:
	if _boss_down:
		return
	_boss_down = true
	if _wave == 1:
		_show_wave_card()
	elif _wave == 2:
		GameState.objective_text = "目标　区域已肃清 · 进入第三波"
		_show_wave3_card()
	elif _wave == 3:
		GameState.objective_text = "目标　第三波通关"

func _show_wave_card() -> void:
	_card = get_tree().get_first_node_in_group("wave_card")
	if _card == null:
		_start_wave2()
		return
	get_tree().paused = true
	if _card.has_method("present"):
		_card.present("第二波 · WAVE 2", "深巢反扑", "DEEP NEST COUNTEROFFENSIVE")
	if not _card.is_connected("continued", _on_card_continued):
		_card.continued.connect(_on_card_continued)

func _show_wave3_card() -> void:
	_card = get_tree().get_first_node_in_group("wave_card")
	if _card == null:
		_start_wave3()
		return
	get_tree().paused = true
	if _card.has_method("present"):
		_card.present("第三波 · WAVE 3", "规则剥夺", "RULE EXTRACTION")
	if not _card.is_connected("continued", _on_wave3_card_continued):
		_card.continued.connect(_on_wave3_card_continued)

func _on_card_continued() -> void:
	get_tree().paused = false
	_start_wave2()

func _on_wave3_card_continued() -> void:
	get_tree().paused = false
	_start_wave3()

func _start_wave2() -> void:
	_wave = 2
	_wave2_started = true
	_wave2_t = 0.0
	_reinforced = false
	_boss_down = false   # 允许第二波 BOSS 再次触发 _on_boss_defeated
	GameState.objective_text = "目标　深巢反扑 · 第二波"
	# 把三只新怪注入 Spawner 随机池，之后常规刷怪会大量混出它们
	var spawner: Node = get_parent().get_node_or_null("Spawner")
	if spawner and spawner.has_method("add_variant"):
		spawner.add_variant(CORRODER)
		spawner.add_variant(BURROWER)
		spawner.add_variant(BLOOM)
	# 开场立刻来一批，且刷在玩家视野内（旧版 420~620 全在屏外，弹卡后看不到新怪）
	_spawn_immediate(CORRODER, 2)
	_spawn_immediate(BURROWER, 2)
	_spawn_immediate(BLOOM, 1)

func _start_wave3() -> void:
	_wave = 3
	_wave3_started = true
	_wave3_t = 0.0
	_wave3_reinforced = false
	_boss_down = false
	GameState.objective_text = "目标　规则剥夺 · 第三波"
	# 把四只 Wave 3 变种注入 Spawner 随机池
	var spawner: Node = get_parent().get_node_or_null("Spawner")
	if spawner and spawner.has_method("add_variant"):
		spawner.add_variant(MIRROR)
		spawner.add_variant(FALSE_BLOOM)
		spawner.add_variant(LINKER)
		spawner.add_variant(WRAITH)
	# 开场立刻来一批，且刷在玩家视野内
	_spawn_immediate(MIRROR, 1)
	_spawn_immediate(FALSE_BLOOM, 2)
	_spawn_immediate(LINKER, 2)  # 至少 2 只才能配对
	_spawn_immediate(WRAITH, 1)

func _wave3_reinforce() -> void:
	# 中途补一批，避免玩家清完开场怪后空场干等 BOSS
	_spawn_immediate(MIRROR, 1)
	_spawn_immediate(LINKER, 2)
	_spawn_immediate(WRAITH, 1)

func _wave2_reinforce() -> void:
	# 中途补一批，避免玩家清完开场怪后空场干等 BOSS
	_spawn_immediate(BURROWER, 2)
	_spawn_immediate(CORRODER, 1)
	_spawn_immediate(BLOOM, 1)

func _spawn_immediate(stats: EnemyStats, n: int) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var pool: Node = get_tree().get_first_node_in_group("enemy_pool")
	if pool == null:
		return
	for i in n:
		var e: Node2D = pool.acquire(get_tree().current_scene) as Node2D
		if e == null or not e.has_method("configure"):
			continue
		e.configure(stats)
		var angle: float = randf() * TAU
		var r: float = randf_range(wave2_spawn_min, wave2_spawn_max) if _wave == 2 else randf_range(wave3_spawn_min, wave3_spawn_max)
		e.global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * r
		# Wave 3 链结对注册：两只 linker 配对
		if stats.behavior == "linker":
			_register_linker_pair(e)

## 注册 linker 对：收集场上的 linker，两两配对
var _pending_linkers: Array = []
func _register_linker_pair(new_enemy: Node2D) -> void:
	_pending_linkers.append(new_enemy)
	if _pending_linkers.size() >= 2:
		var a := _pending_linkers[0] as Node2D
		var b := _pending_linkers[1] as Node2D
		_pending_linkers = []
		if a and b and a.has_method("_register_link") and b.has_method("_register_link"):
			a._register_link(b.get_instance_id(), b.stats)
			b._register_link(a.get_instance_id(), a.stats)
