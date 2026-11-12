# 《孢城 SPORE FALL》Godot 4.7 垂直切片工程

> 对应策划文档：`C:/Users/minji/Desktop/object/生化危机式生存游戏-设计方案.md` 的 **§11 Godot 4 垂直切片清单**。
> 目标：把「随机刷怪 + 自动索敌 + 无尽循环 + Juice 爽刷」从纸面跑成可在 Godot 4.7 打开的可玩原型。

## 如何打开运行

1. 用已安装的 **Godot 4.7** 打开本文件夹（`spore-fall/`）作为项目（Project → Import / Open）。
2. 按 F5 运行主场景 `res://scenes/world/Arena.tscn`。
3. 操作：**WASD / 方向键** 移动，**空格** 攻击（消耗弹药 + hitstop），**E** 互动（预留）。手机端左半屏虚拟摇杆走位 + 右下 FIRE 按住连发，**开火自动锁定 560px 内最近的敌人**，不用为了瞄准而改变走位。
4. 攒满孢子晶体（6 / 8 / 10 … 颗，逐级递增）会**暂停并弹出三选一强化卡**：点击卡片选择，PC 也可按 **1 / 2 / 3**。选完立刻恢复战斗，每局能长出不同 Build。

## 工程结构

```
spore-fall/
├─ project.godot              # 工程配置：主场景 + 7 个 Autoload + GL Compatibility
├─ main.gd                    # Autoload: GameState（计时/分数/难度档/连杀/最高分/升级点 mods + 代码注册 InputMap）
├─ core/EventBus.gd           # Autoload: 解耦事件总线
├─ scenes/
│  ├─ world/Arena.tscn        # 主战场（y_sort + 导航区 + TileMap + 黑暗 + 玩家 + 刷怪器 + 相机 + HUD 层）
│  ├─ world/Player.tscn       # 主角（CharacterBody2D + Sprite2D + PointLight2D 手电锥光 + 碰撞）
│  ├─ world/Enemy.tscn        # 敌人（CharacterBody2D + NavAgent + 击杀粒子 + 碰撞）
│  └─ ui/HUD.tscn             # 分数/连杀/存活时长
├─ scripts/
│  ├─ world/Arena.gd          # 启动无尽循环（start_run）
│  ├─ world/CameraShake.gd    # 读 Juice.trauma 做屏幕震动
│  ├─ player/Player.gd        # 移动 + 攻击
│  ├─ enemy/Enemy.gd          # 自动索敌（含无导航网格兜底）+ 受击死亡 + 击杀粒子
│  ├─ enemy/EnemyStats.gd     # 敌人参数谱 Resource（五维数据驱动）
│  ├─ enemy/Spawner.gd        # 环外随机刷怪 + 难度缩放间隔
│  ├─ systems/Inventory.gd    # 弹药/草药/血清背包
│  ├─ systems/DifficultyCurve.gd # 难度缩放工具（静态方法）
│  ├─ systems/CareerStats.gd  # Autoload: 生涯统计 + 成就（user://career.cfg）
│  ├─ systems/UpgradePool.gd  # 三选一卡池数据（8 张卡 + 叠加上限 + 抽取）
│  ├─ fx/Juice.gd             # Autoload: hitstop + 屏震 trauma
│  ├─ ui/HUD.gd               # 读取 GameState 显示 + 成就/升级 toast
│  └─ ui/UpgradeUI.gd         # 暂停三选一选卡界面（scenes/ui/UpgradeUI.tscn）
├─ shaders/outline.gdshader   # 2D 卡通反向外扩描边（赋给 Sprite2D 的 Material）
└─ assets/                    # 美术成品已接入：玩家 + 5 变种专属贴图（256px 透明底，与图标同调的孢子生物风格），程序化渐变仅剩地面 TileMap
```

## 已接通的系统（对照 §11.7 DoD）

| DoD 项 | 状态 | 说明 |
|---|---|---|
| 单局可玩：移动 + 怪物环外刷新并自动追 | ✅ | Spawner 环外随机点 + Enemy 直接索敌（导航网格绘后自动走避障） |
| 难度随时间单调上升 | ✅ | `GameState` 计时 → 难度档 → `DifficultyCurve` 缩短刷怪间隔 |
| 卡通描边 + 手电锥光 + 战争迷雾 | ✅ | `outline.gdshader` 就绪（需赋给 Sprite 材质）；`CanvasModulate` 黑暗已开；`PointLight2D` 手电已接 `GradientTexture2D` 径向柔光锥，跟随移动方向旋转（真扇形硬边遮罩待美术补 PNG） |
| Juice 爽刷（≥3 项） | ✅ | hitstop + 屏幕震动 trauma + 连杀 combo（击杀粒子也已接） |
| 死亡即结算 | ✅ | 玩家血量 + 敌人接触掉血；死亡触发 `GameState.end_run()` → 完整死亡演出（慢动作+镜头推近）→ `GameOver` 深色结算面板（分数/存活时长 + 重开/退出） |
| 精英/Boss 高潮点（§11.4.4） | ✅ | 3/8/15 分召唤「母巢孢」：登场震屏+低频吼 + 顶部血条（`BossBar`）+ 蓄力冲锋（前摇变红可躲）+ 战斗期间暂停常规刷怪 + 击杀 600 分撒一圈晶体；每轮血量 ×(1+1.4n) 递增抵消武器成长 |
| 标题界面与开局流转 | ✅ | `Title.tscn` 为主场景：孢城标题 + 背景浮尘氛围（纯 _draw）+ 开始/画质/退出 + 本地最高分（`user://save.cfg`）；结算页新增「返回标题」，破纪录时标题变金色「新 纪 录」；PC/手机各一行操作提示 |
| 伏击体行为分支（§11.5） | ✅ | 新变种「潜伏孢 Lurker」：半埋潜伏（45% 透明度、静止、不吃接触伤害）→ 玩家进警觉半径 340px → 破土前摇 0.35s（变红+弹跳+音效）→ 175 满速追击；`behavior` 字段真正驱动 AI 分支，改 .tres 即换行为 |
| 美术统一重绘 | ✅ | 每个变种一张专属贴图（walker/runner/brute/lurker/boss + 玩家，256px 透明底）：`EnemyStats.sprite_texture` 数据驱动，`_apply_visual` 池化复用双向切换；原图 512px AI 生成 → `tools/make_sprites.gd` 白底泛洪剔除 + 主体归一化 210px 合成透明画布；贴图分辨率无关（换图只调 `BASE_SCALE`） |
| 死亡血渍残迹 | ✅ | 击杀原地留一滩变种专属颜色体液渍（`EnemyStats.blood_color` 数据驱动：青/黄绿/紫/暗紫/洋红）：`BloodPool` 纯 _draw 程序化斑点（主斑+卫星溅点+浓稠内芯，零贴图零粒子），0.16s 溅开 → 3.6s 存留 → 1.1s 淡出自毁；同屏封顶 50（低档 20），Boss 按 scale_mult 2.8 放大 |
| 走位可摆脱怪群 | ✅ | 碰撞分层：玩家层 2 只撞柱子、敌人层 4 撞柱子+同类、子弹 mask 5——玩家物理上穿过怪群（接触伤害走距离判定保留），怪互撞保持群体阵型不叠点；探针 probe_bullet_layer.gd 验证子弹命中与贴身掉血双链路 |
| 击杀爆裂演出 | ✅ | `DeathBurst`：本体即时回池、视觉替身留原地播完。阶段A 0.10s 过曝白剪影 + 1.55× 膨胀 + 白色冲击环 → 阶段B 炸成贴图碎片（Atlas 随机区块）+ 血色脓滴四散下坠自旋 → 0.62s 淡出自毁；单 CanvasItem 纯 `_draw` 零粒子/零 Tween 节点，同屏封顶 24，低画质减半碎片，Boss 按 scale_mult 2.8 放大至 19 片 |
| 毒雾孢 Miasma（§11.5 M4） | ✅ | 死亡原地留毒绿雾区（`PoisonCloud` 纯 _draw 脉动雾团 + 亮绿边界环）：半径 78 / 持续 4s / 10 dps 每 0.5s 结算，按真实时间推进不受 hitstop 拖长，末尾 0.9s 淡出；封顶 12（低档 6）。区域封锁逼玩家走位 |
| 分裂孢 Splitter（§11.5 M4） | ✅ | 死亡裂出 2 只迷你子体：同参数谱 + 血量 ×0.45 + 体型 ×0.62，子体带防递归标记（死亡不再分裂），活跃数 ≥140 时放弃分裂守住性能；池化复用清标记。`behavior` 数据驱动的第三、四条分支 |
| 移动端瞄准与移速平衡 | ✅ | 原先「射击方向 = 最后移动方向」，摇杆既走位又瞄准，手机上想打左边就得往左走。现开火自动锁 560px 内最近活敌（跑动时朝移动方向的目标 30% 加权），摇杆只管走位；无目标回退最后移动方向。开关 `TouchInput.auto_aim`（置 false 回老手感）。同时全变种移速下调 20%（玩家 220 不变，突围余量更大），Boss 冲锋倍率 4.0→5.0 单独补偿，保持 250px/s 的威胁 |
| 生涯统计 + 成就（§11.8） | ✅ | `Career` Autoload（`user://career.cfg`，与 `best_score` 的 `save.cfg` 分离）：累计局数/击杀/时长、最长存活、最高连杀、单局最高击杀；6 个成就（初入孢城 / 百孢斩 / 千孢斩 / 持久战 / 连杀狂人 / 高分猎手）。累计击杀与存活时长**局内实时解锁**并由 HUD 顶部固定 toast 提示（不挤动布局），单局成就结算时判定；结算页展示生涯摘要 + 本局新成就金色行，标题页展示「N 局 · 累计击杀 · 成就 x/6」。两个存档路径均可写，探针改临时文件不污染真实进度 |
| 局内三选一升级卡（§11.11） | ✅ | 晶体攒满（6/8/10… 颗，比原先 3/4/5 稀疏一倍，不打断爽刷）→ **暂停 → 三选一 → 恢复**：8 张卡、每卡有叠加上限，卡池数据 `UpgradePool` 与效果完全解耦，只改 `GameState.mods` 乘区/加区，由 `Player` / `Bullet` / `Pickup` 各自读取重算。覆盖射速、伤害、弹道数、移速、最大生命、磁吸、**子弹穿透**、弹速射程八个维度；选卡界面根节点 `PROCESS_MODE_ALWAYS`，鼠标/触屏与键盘 1/2/3 在暂停中都能操作，关闭时复位摇杆与 FIRE 按住状态；HUD 顶部 toast 与结算/标题的 BUILD 计数同步 |
| 画质档位（§11.6） | ✅ | `Quality` Autoload 三档（低/中/高）：描边 pass 开关、粒子数量比例（1.0/0.7/0.35）、手电光强与半径；HUD 右上按钮实时切换 + `user://settings.cfg` 持久化；手机默认中档、桌面默认高档 |
| 手机虚拟摇杆可跑 | 🟡 待真机 | 手感参数已按移动端标准调优：死区 0.18 + 全量程重映射、按下弹入/松手淡出、力度可视化、左半屏任意点起杆、FIRE 键滑出不误停；探针 probe_touch.gd 全过，仅剩真机手测 |
| 同屏 100+ 60fps | ✅ | 实测（Intel UHD 集显、关垂直同步）：100 只 277–297fps / 200 只 162–201fps，p95 帧时间 7.1–12.5ms（60fps 预算 16.6ms）；对象池复用 + 同屏封顶 150 + 避障射线节流 |

## 切片范围（已做 / 未做）

**已做**：无尽核心循环骨架、随机刷怪、自动索敌、难度缩放、Juice 三件套、HUD、2.5D 节点结构（y_sort）、卡通描边 shader、双端输入抽象、角色美术成品（玩家 + 5 变种专属贴图）。
**未做（明确 out of scope）**：剧情战役/对话/据点、全部敌人变种与命名 Boss、地面 TileMap 成品贴图、导航网格避障。

## 后续 TODO（按优先级）

1. ~~**玩家受伤与死亡结算**（已完成）：`Player` 血量 + `Enemy` 接触掉血 + `GameOver` 结算界面（分数/存活/重开）。~~
2. ~~**子弹命中**（已完成）：`Player._attack()` 生成 `Bullet`（Area2D），命中 `enemy` 组敌人调 `enemy.take_damage()`，HUD 弹药计数已接。~~
3. **导航网格**：在 Arena 的 `NavigationRegion2D` 里绘制 `NavigationPolygon`，敌人即从「直接追」切到「避障寻路」。
4. ~~**手电纹理**（已完成）：`Player.tscn` 的 `Flashlight` 节点已用 `PointLight2D` + `GradientTexture2D` 径向渐变做柔光锥，跟随移动方向旋转。真扇形硬边光锥待补一张锥光 PNG 遮罩（可后续用 agnes-image 生成）。~~
5. ~~**美术占位替换**（已完成）：AI 生成 6 张 512px 角色原图（agnes-image，与图标同风格）→ `tools/make_sprites.gd` 白底泛洪剔除（只清与边缘连通的白色，保留主体内部高光）+ 主体长边归一化 → 256px 透明画布合成；`EnemyStats.sprite_texture` 挂到 5 个 .tres，玩家贴图直连 `Player.tscn`。~~
6. **手机端**：摇杆手感调优完成，待真机验证一局完整流程（连上 `adb` 后 `adb install build/SporeFall-0.1.0.apk`）。
7. ~~**对象池**（已完成）：Spawner/Bullet 全走 `ObjectPool` 预实例化池（§11.9），停车场复位防残余碰撞。~~
8. ~~**画质档位（§11.6）**（已完成）：`Quality` Autoload 三档实时切换，描边/粒子/光源全接，`user://` 持久化。~~
9. ~~**性能压测（§11.7）**（已完成）：见下方性能基线。~~
10. ~~**应用 Icon 与启动闪屏**（已完成）：AI 生成孢子生物图标（agnes-image）→ `tools/make_icons.gd` 裁边 + 圆角透明 + 全套尺寸 → `tools/make_ico.py` 合成 Windows ICO。EXE / APK（legacy + adaptive）/ 工程图标 / 启动闪屏全部替换。~~

11. ~~**死亡血渍残迹 + 走位摆脱怪群**（已完成）：`BloodPool` 程序化血渍（变种专属色、溅开→存留→淡出）+ 碰撞分层（玩家穿怪、怪保阵型、子弹照常命中）。~~
12. ~~**击杀爆裂演出**（已完成）：`DeathBurst` 闪白膨胀+冲击环→贴图碎片+脓滴四散→淡出，池化替身留场播完、本体即时回池。~~
13. ~~**M4 新变种：毒雾孢 / 分裂孢**（已完成）：agnes-image 图生图（以现有贴图为风格锚点）→ 后处理接入；`behavior` 第三/四条数据驱动分支，死亡留毒雾区 / 裂出防递归迷你子体。~~
14. ~~**移动端瞄准与移速平衡**（已完成）：自动锁定最近敌人让走位与开火解耦；全变种移速 −20%，Boss 冲锋倍率补偿。~~
15. ~~**生涯统计 + 成就系统**（已完成）：`Career` 跨局沉淀 + 6 个成就 + 局内 toast / 结算页 / 标题页三处展示；结算时收起浮在遮罩上的触屏 FIRE 键。~~
16. ~~**局内三选一升级卡**（已完成）：把「攒满晶体静默自动升级」换成「暂停 → 三选一 → 继续」，8 张卡构成每局不同的 Build；详见下方专节。~~

## 品牌资产（assets/icons/）

| 文件 | 用途 |
|---|---|
| `icon_1024.png` | 项目主图标（`project.godot config/icon`） |
| `icon.ico` | Windows EXE 内嵌图标（256/128/64/48/32/16） |
| `icon_192.png` | Android legacy launcher 图标 |
| `icon_adaptive_432.png` + `icon_adaptive_bg.png` | Android 自适应图标前/背景层 |

重新生成流程：agnes-image 出 1024 原图存 `build/icon_raw.png` → `Godot --headless --script tools/make_icons.gd` → `python tools/make_ico.py` → 重导出双端包。

## 角色贴图（assets/characters/）

| 文件 | 挂载点 |
|---|---|
| `player.png` | `Player.tscn`（BASE_SCALE 0.2） |
| `enemy_walker/runner/brute/lurker/boss.png` | 各 `enemy_*.tres` 的 `sprite_texture`（Enemy BASE_SCALE 0.19 × 变种 scale_mult） |
| `enemy_miasma/splitter.png` | 新增 M4 变种专属贴图（同为 512px 图生图 → 256px 透明画布） |

重新生成流程：agnes-image 出 512px 原图存 `build/sprites_raw/` → `Godot --headless --script tools/make_sprites.gd`（白底泛洪剔除 + 主体归一化 210px）→ 自动写回 `assets/characters/`。注意屏幕上环宽 = outline_width(texel) × sprite_scale，换贴图分辨率只需调 scale。

## 局内升级卡（§11.11）

**为什么改**：原先晶体攒满后 `GameState.weapon_level` 静默 +1，成长完全隐形、每局体验一模一样。爽刷品类的核心乐趣是「这局长出什么 Build」，所以把自动升级换成有决策的三选一。

**链路**：

```
拾取晶体 → GameState.add_crystal() 攒满（6 / 8 / 10 … 颗，按 weapon_level 递增）
  → weapon_level +1（基础成长保留）+ upgrade_ready(UpgradePool.pick(taken))
  → UpgradeUI 监听：get_tree().paused = true，展示三张卡（触屏/鼠标点击 或 键盘 1/2/3）
  → GameState.apply_upgrade(id)：只累加 GameState.mods，广播 upgrade_applied
  → UI 恢复 paused = false + 复位摇杆/FIRE；HUD 弹「获得强化」toast
```

**架构约束**：卡池数据（`scripts/systems/UpgradePool.gd`）与效果彻底解耦。`mods` 里乘区默认 `1.0`、加区默认 `0`，`Player` 在 `_apply_weapon_level()` 合流基础成长与加成，`Bullet` 在 `setup()` 发射瞬间取快照，`Pickup.magnet_radius()` 每帧读取（场上已有晶体立刻吃到加成）。**任何系统都不认识「卡片」这个概念**，加第九张卡只需在 `CARDS` 里加一行 + 在 `apply_upgrade` 加一个 match 分支。

| 卡 | 效果 | 上限 |
|---|---|---|
| 疾速孢子 / 尖刺孢囊 | 射速 +15% / 伤害 +20%（乘区） | 6 / 8 |
| 分裂射 / 贯穿孢针 | 弹道 +1 / 穿透 +1（加区） | 4 / 3 |
| 轻足 / 厚壁 | 移速 +12% / 最大生命 +25 且立即回 25 | 4 / 6 |
| 引力场 / 疾风孢针 | 磁吸半径 +30% / 弹速 +25%（射程同步变长） | 4 / 4 |

**几个刻意的实现取舍**：

- 门槛从 3/4/5 颗拉到 6/8/10…：选卡要暂停，太密会打断爽刷节奏，一局约 4~7 次选择刚好。
- `UpgradeUI` 根节点 `PROCESS_MODE_ALWAYS`：暂停时它自己还要收输入，用默认 PAUSABLE 会把卡片一起冻住。触屏/鼠标命中在 `_input` 里按卡片矩形自己判定，不赌「暂停时 Button 还收不收 GUI 输入」；命中后 `accept_event()` 防止 Button 重复触发。
- 关闭弹窗调 `TouchControls.reset_input()`：暂停期间手指松开的事件会丢，不复位的话恢复瞬间角色自己走 / FIRE 自动连发。
- `Bullet.pierce` 用 `_hit_ids` 去重，且柱子照常销毁子弹（穿透只穿怪，不破坏掩体博弈）；`fire_interval` 有 0.045s 下限，防止叠满射速卡后一帧多发炸物理。
- 不做入场 Tween 动画：暂停中的 Tween 推进受 process_mode 影响，宁可「立刻可读」。

验证：`tests/probe_upgrade.gd`（14 项断言，卡池/稀疏门槛/暂停/点击/键盘/mods/Player/Bullet/Pickup/HUD/结算兜底/重开重置）、`tests/probe_upgrade_click.gd`（**必须真渲染**，验证暂停中真实鼠标点击；`--headless` 下 dummy 字体度量会把 VBox 撑高、卡片矩形算到 y≈617 而打空）、`tests/shot_upgrade.gd`（两张视觉截图）。

## 性能基线（§11.7）

测试脚本 `tests/stress_test.gd`（关垂直同步、固定敌人数、每档跑 6s，取中位数与 p95）：

| 同屏敌人 | 画质档 | 平均帧率 | 中位帧时 | p95 帧时 | Draw calls |
|---|---|---|---|---|---|
| 100 | 高 | 277 fps | 3.01 ms | 7.64 ms | 317 |
| 100 | 中 | 292 fps | 2.79 ms | 7.27 ms | 317 |
| 100 | 低 | 297 fps | 2.83 ms | 7.11 ms | 216 |
| 200 | 高 | 162 fps | 4.89 ms | 12.52 ms | 617 |
| 200 | 中 | 174 fps | 4.50 ms | 11.95 ms | 616 |
| 200 | 低 | 201 fps | 3.68 ms | 11.21 ms | 415 |

测试机：Intel UHD Graphics（集显/GL Compatibility）。60fps 预算 16.6ms，最差 p95（200 只/高档）为 12.5ms，仍有约 25% 余量。
描边 pass 的代价约 **+100 draw calls / 100 敌人（+47%）**，低档直接砍掉，是移动端最有效的一刀。

> ⚠️ 手机真机（arm64 APK）尚未实测；若中低端机掉帧，优先切「画质 低」（粒子 0.35 / 无描边 / 光半径 3.6）。

> 引擎已定 Godot 4（§5.3 / §11），开源免费、2D 管线成熟。本工程用 GL Compatibility 渲染后端，兼容性与低端机更稳。

## 导出与交付

- Windows：`Godot --headless --path . --export-release "Windows Desktop"` → `build/SporeFall.exe`
- Android：`Godot --headless --path . --export-debug "Android"` → `build/SporeFall-0.1.0.apk`（真机可安装的 debug 签名；`--export-release` 需要先配 release keystore）
- 两个 preset 都设了 `exclude_filter="build/*, tests/*"`：验证截图、AI 原图与探针脚本不进包，EXE 约 109MB / APK 约 32MB，比全量导出各小约 10MB。`build/` 本身被 `.gitignore` 排除，包与截图只作本地交付。
