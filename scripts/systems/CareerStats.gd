extends Node
# 生涯统计 + 成就（§11.8）：把每局战绩沉淀成跨局成长反馈。
# user://career.cfg 独立于 best_score 的 save.cfg，互不影响。
# 实时成就（累计击杀 / 存活时长）在局内解锁并广播 toast；单局成就在结算时判定。

const ACHIEVEMENTS := [
	{"id": "first_run", "name": "初入孢城", "desc": "完成 1 局"},
	{"id": "kills_100", "name": "百孢斩", "desc": "累计击杀 100"},
	{"id": "kills_1000", "name": "千孢斩", "desc": "累计击杀 1000"},
	{"id": "survive_300", "name": "持久战", "desc": "单局存活 5 分钟"},
	{"id": "combo_25", "name": "连杀狂人", "desc": "单局最高连杀 25"},
	{"id": "score_5000", "name": "高分猎手", "desc": "单局 5000 分"},
]

# 可写路径：探针改成临时文件，避免污染玩家真实存档
var save_path: String = "user://career.cfg"

var total_runs: int = 0
var total_kills: int = 0
var total_playtime: float = 0.0
var best_survival: float = 0.0
var best_combo: int = 0
var best_kills: int = 0
var unlocked: Dictionary = {}
var run_new: Array[String] = []      # 本局新解锁（结算页展示）

func _ready() -> void:
	_load()

func reset_run() -> void:
	run_new.clear()

# ---------- 局内实时判定 ----------
func note_kill() -> void:
	total_kills += 1
	if total_kills >= 100:
		_unlock("kills_100")
	if total_kills >= 1000:
		_unlock("kills_1000")

func note_time(t: float) -> void:
	if t >= 300.0:
		_unlock("survive_300")

# ---------- 结算 ----------
func record_run(score: int, survived: float, kills: int, max_combo: int) -> void:
	total_runs += 1
	total_playtime += survived
	best_survival = maxf(best_survival, survived)
	best_combo = maxi(best_combo, max_combo)
	best_kills = maxi(best_kills, kills)
	_unlock("first_run")
	if score >= 5000:
		_unlock("score_5000")
	if max_combo >= 25:
		_unlock("combo_25")
	_save()

func _unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	for a in ACHIEVEMENTS:
		if a.id == id:
			run_new.append(a.name)
			EventBus.achievement_unlocked.emit(a.name)
			break
	_save()   # 解锁立即落盘，中途退出不丢

# ---------- 展示 ----------
func unlocked_count() -> int:
	return unlocked.size()

func summary() -> String:
	var mins := floori(best_survival / 60.0)
	var secs := int(best_survival) % 60
	return "生涯  %d 局 · 累计击杀 %d · 最长存活 %d:%02d" % [
		total_runs, total_kills, mins, secs]

func title_line() -> String:
	if total_runs <= 0:
		return ""
	return "%d 局 · 累计击杀 %d · 成就 %d/%d" % [
		total_runs, total_kills, unlocked_count(), ACHIEVEMENTS.size()]

func achievement_line() -> String:
	if run_new.is_empty():
		return ""
	return "★ 新成就　" + " ／ ".join(run_new)

# ---------- 持久化 ----------
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	total_runs = int(cfg.get_value("career", "total_runs", 0))
	total_kills = int(cfg.get_value("career", "total_kills", 0))
	total_playtime = float(cfg.get_value("career", "total_playtime", 0.0))
	best_survival = float(cfg.get_value("career", "best_survival", 0.0))
	best_combo = int(cfg.get_value("career", "best_combo", 0))
	best_kills = int(cfg.get_value("career", "best_kills", 0))
	for id in String(cfg.get_value("achievements", "unlocked", "")).split(",", false):
		unlocked[id] = true

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("career", "total_runs", total_runs)
	cfg.set_value("career", "total_kills", total_kills)
	cfg.set_value("career", "total_playtime", total_playtime)
	cfg.set_value("career", "best_survival", best_survival)
	cfg.set_value("career", "best_combo", best_combo)
	cfg.set_value("career", "best_kills", best_kills)
	cfg.set_value("achievements", "unlocked", ",".join(PackedStringArray(unlocked.keys())))
	cfg.save(save_path)
