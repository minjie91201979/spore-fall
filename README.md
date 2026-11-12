# 《孢城 SPORE FALL》Godot 4.7 垂直切片工程

> 对应策划文档：`C:/Users/minji/Desktop/object/生化危机式生存游戏-设计方案.md` 的 **§11 Godot 4 垂直切片清单**。
> 目标：把「随机刷怪 + 自动索敌 + 无尽循环 + Juice 爽刷」从纸面跑成可在 Godot 4.7 打开的可玩原型。

## 如何打开运行

1. 用已安装的 **Godot 4.7** 打开本文件夹（`spore-fall/`）作为项目（Project → Import / Open）。
2. 按 F5 运行主场景 `res://scenes/world/Arena.tscn`。
3. 操作：**WASD / 方向键** 移动，**空格** 攻击（消耗弹药 + hitstop），**E** 互动（预留）。

## 工程结构

```
spore-fall/
├─ project.godot              # 工程配置：主场景 + GameState/EventBus/Juice 三个 Autoload + GL Compatibility
├─ icon.svg
├─ main.gd                    # Autoload: GameState（计时/分数/难度档/连杀 + 代码注册 InputMap）
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
│  ├─ fx/Juice.gd             # Autoload: hitstop + 屏震 trauma
│  └─ ui/HUD.gd               # 读取 GameState 显示
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

重新生成流程：agnes-image 出 512px 原图存 `build/sprites_raw/` → `Godot --headless --script tools/make_sprites.gd`（白底泛洪剔除 + 主体归一化 210px）→ 自动写回 `assets/characters/`。注意屏幕上环宽 = outline_width(texel) × sprite_scale，换贴图分辨率只需调 scale。

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
