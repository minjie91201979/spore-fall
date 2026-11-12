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
└─ assets/                    # 美术占位（当前为程序化 GradientTexture2D 渐变占位：玩家青蓝/敌人红橙/地面灰蓝，真美术成品待替换）
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
| 手机虚拟摇杆可跑 | 🟡 待实机验证 | 虚拟摇杆 + FIRE 按钮已接 `TouchInput` 统一动作，需真机跑一局 |
| 同屏 100+ 60fps | 🟡 待压测 | 对象池已接（敌人/子弹预实例化），待中端机实测帧率 |

## 切片范围（已做 / 未做）

**已做**：无尽核心循环骨架、随机刷怪、自动索敌、难度缩放、Juice 三件套、HUD、2.5D 节点结构（y_sort）、卡通描边 shader、双端输入抽象。
**未做（明确 out of scope）**：剧情战役/对话/据点、全部敌人变种与命名 Boss、美术成品（当前为程序化渐变占位，真角色/地面图待 agnes-image 生成替换）、对象池性能优化、导航网格避障。

## 后续 TODO（按优先级）

1. ~~**玩家受伤与死亡结算**（已完成）：`Player` 血量 + `Enemy` 接触掉血 + `GameOver` 结算界面（分数/存活/重开）。~~
2. ~~**子弹命中**（已完成）：`Player._attack()` 生成 `Bullet`（Area2D），命中 `enemy` 组敌人调 `enemy.take_damage()`，HUD 弹药计数已接。~~
3. **导航网格**：在 Arena 的 `NavigationRegion2D` 里绘制 `NavigationPolygon`，敌人即从「直接追」切到「避障寻路」。
4. ~~**手电纹理**（已完成）：`Player.tscn` 的 `Flashlight` 节点已用 `PointLight2D` + `GradientTexture2D` 径向渐变做柔光锥，跟随移动方向旋转。真扇形硬边光锥待补一张锥光 PNG 遮罩（可后续用 agnes-image 生成）。~~
5. **美术占位替换**：把 `assets/` 的精灵接进 Player/Enemy 的 Sprite2D，并挂 `outline.gdshader` 材质。
6. **手机端**：虚拟摇杆已接，待真机验证一局完整流程。
7. ~~**对象池**（已完成）：Spawner/Bullet 全走 `ObjectPool` 预实例化池（§11.9），停车场复位防残余碰撞。~~
8. **画质档位（§11.6）**：描边开关、光源上限、雾分辨率、粒子上限，低端机降级保 60fps。
9. **性能压测（§11.7）**：同屏 100+ 敌人帧率实测与调优。

> 引擎已定 Godot 4（§5.3 / §11），开源免费、2D 管线成熟。本工程用 GL Compatibility 渲染后端，兼容性与低端机更稳。
