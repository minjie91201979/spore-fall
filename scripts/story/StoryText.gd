extends RefCounted
class_name StoryText
# 序章与安全屋文案。句子都来自剧情方案，不在这里另写情节。

const PROMPT_NEAR := "按 E 调查 / 手机：点「互动」"
const PROMPT_USE := "按 E 使用"
const PROMPT_TERMINAL := "值班终端　·　按 E 保存进度"
const SAVE_DONE := "进度已写入第3检疫所正压库。"
const OBJECTIVE_GATE := "目标　前往第3检疫所"
const OBJECTIVE_PROLOGUE := "目标　序章　雨夜抵达"
const DATE_LINE := "潮汐工业特区　11月12日　夜"
const CHAPTER_RESULT := "第3检疫所　·　正压库已建立"

static func line(speaker: String, text: String, radio: bool = false) -> Dictionary:
	return {"speaker": speaker, "text": text, "radio": radio}

static func radio(text: String) -> Dictionary:
	return line("路晚棠（无线电）", text, true)

static func intro() -> Array:
	return [
		radio("听得见吗？听得见就别先往主路走。"),
		radio("……算了，你大概已经想走了。"),
		radio("我是第3检疫所通讯室，路晚棠。你是沈见秋？"),
		line("沈见秋", "对。市里说是培养层微量泄漏。"),
		radio("市里说什么你先放一边。你现在在东关卡，对吧？"),
		radio("主路的隔离网已经倒了。沿着有黄漆栏杆的辅道走，一直走到有青灯的那栋。"),
		radio("那是检疫所。门禁我给你开过一次，别磨蹭。"),
	]

static func road_again() -> Array:
	return [
		radio("听得见吗？听得见就别先往主路走。"),
		radio("主路的隔离网已经倒了。沿着有黄漆栏杆的辅道走，一直走到有青灯的那栋。"),
	]

static func after_first_walker() -> Array:
	return [
		radio("它还会动的时候，别靠近嘴里那层膜。"),
		radio("你要是中招，我这边的灯会比你自己先知道。"),
		line("沈见秋", "你能看见我？"),
		radio("看见生命体征，看不见你那张脸。别得意。"),
	]

static func on_brute() -> Array:
	return [radio("绕到柱子后面，让它自己转弯。")]

static func on_cyan() -> Array:
	return [
		radio("看见青灯了就对了。门在你右边，先进正压库。"),
		radio("左边那扇窗是我。别来砸，砸不开，还浪费子弹。"),
	]

static func low_ammo() -> Array:
	return [radio("弹匣见底了。补给箱在门口那种铁皮匣子里，或者你回我这儿来。")]

static func low_health() -> Array:
	return [radio("你的灯在跳。吃掉身上的药，别省。")]

static func window_lines() -> Array:
	return [
		line("沈见秋", "有人吗。市级防疫，外勤核查。"),
		line("沈见秋", "……人已经不在了。"),
	]

static func file_line() -> Array:
	return [line("沈见秋", "值班员走主路了。通知上可没写这一句。")]

static func arrival() -> Array:
	return [
		radio("门会自己合上。里面是正压，孢子进不去。"),
		radio("我在隔壁通讯室。门框变形了，我暂时出不去——所以别指望我下楼给你开门。"),
		radio("终端可以保存进度。药和子弹在铁柜里，能用的不多，别当超市。"),
		line("沈见秋", "通知上写核查不超过两小时。"),
		radio("那张通知要是管用，我现在该在喝水，而不是跟你说话。"),
	]

static func amang_meet() -> Array:
	return [
		line("阿芒", "哟，活的。"),
		line("阿芒", "我叫阿芒。这屋子是我先找到的，正压还在转，我就把摊支上了。"),
		line("阿芒", "你缺子弹、缺绷带，拿晶体或者零件来换。闲话免费，但别问我青潮发不发赔偿。"),
		line("沈见秋", "沈见秋。防疫外勤。"),
		line("阿芒", "我知道，耳机里那位刚才把你名字报了一遍。沈哥，活着比报告重要。"),
	]

static func retry_contacted() -> Array:
	return [
		radio("体征断过一下。你要是还能听见，就先别逞能。"),
		radio("黄漆栏杆，青灯，正压库。别走主路。我说第二遍。"),
	]

static func retry_silent() -> Array:
	return [
		radio("东关卡有人吗？有人就应一声。"),
		radio("……算我先说。别走主路，走黄漆辅道。听得见就照做。"),
	]

const LU_IDLE: Array[String] = [
	"终端蓝灯亮着就能存。别等子弹打光了再学这个。",
	"通讯室的咖啡已经凉成标本。你不必同情我，把门那边的活干完就行。",
	"正压在耳膜上有一点点胀。那是好事，说明外面还进不来。",
	"市里要是再来电，我会说信号不好。今晚不需要第三份通知。",
	"阿芒的滤罐是自制的。买他的药可以，买他的罐，我建议再想想。",
]

const MANG_IDLE: Array[String] = [
	"晶体我收。发亮的、干的、不黏手的，价高一点。",
	"这屋里最值钱的不是货，是那台还在转的风机。风机一停，我们就都得改行。",
	"沈哥，你这外套是公家的吧。公家的口袋浅，买药的时候记得问价。",
	"关卡那方向我不去。主路倒了之后，风是甜的，甜的东西最贵，也最不能吃。",
	"耳机里那位女士说话是冲，但她没把我赶出去。冲的人里面，这已经算客气。",
]

const GATE_LOG := """潮汐工业特区东关卡　值班记录
日期：11 月 12 日　班次：夜班

19:10　青潮生物的运输车取消入库。对方在对讲里说「厂区自行消化小故障」，不需要市政协助。我把车号记在背面。
20:40　东堤方向有一股甜的、像潮水退下去的气味。不是油，也不是鱼。我向值班室报了一次，对方让我写「可能是培养层湿气」。
21:15　第3检疫所来过呼叫，说正压系统自检正常，通讯室今晚有人值班。声音是女的，没报名字。
22:02　主路隔离网的警报响了一下，又自己停了。我出去看，网还立着，路上没有人。
22:30　我把钥匙留在抽屉第二格。如果下一班看不到我，不要沿主路去东堤。辅道的黄漆栏杆还在。

（以下字迹发湿，有一行被指腹蹭淡）
有东西在网那边站着。我先去看看。它不该站着。"""

const CHAPTERS: Array[Dictionary] = [
	{"id": "prologue", "title": "序章　雨夜抵达", "locked": ""},
	{"id": "m1", "title": "任务一　所谓微量", "locked": "任 务 一　？？？"},
	{"id": "m2", "title": "任务二　还在线上的人", "locked": "任 务 二　？？？"},
	{"id": "m3", "title": "任务三　青潮的门", "locked": "任 务 三　？？？"},
	{"id": "m4", "title": "任务四　向下生长", "locked": "任 务 四　？？？"},
	{"id": "m5", "title": "任务五　把根烧掉", "locked": "任 务 五　？？？"},
]
