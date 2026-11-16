# 《孢城 SPORE FALL》Wave 3 规格说明书 v0.1

> 目标：新增第三波怪物「镜影/伪晶/链结/蚀晶」及 Boss「织理者 Loom Weavers」，与前两波形成叙事、行为、视觉、数值四轴反转。
> 配套文件：`docs/wave3-boss-state-machine.md`、`assets/prompt_wave3.md`

---

## 一、设计目标（DoR — Definition of Ready）

| # | 目标 | 衡量标准 |
|---|---|---|
| G1 | 与 Wave 1-2 拉开差异化 | 新增 4 个 behavior 标签，其中 mirror/false_bloom/linker/wraith 均为**规则级机制**而非单纯换贴图 |
| G2 | 不破坏已有 Build 循环 | 升级卡、晶体拾取、Boss 技能冷却互斥全部复用现有接口 |
| G3 | 可玩性不下降 | 每个新机制都给出明确反制路径（走位/Build 搭配/观察前摇） |
| G4 | 美术统一 | 采用橙/蓝/白噪灰新色轴；帧动画 12fps × 4 帧 |

---

## 二、新怪物清单

### 2.1 镜影孢 `Mirror Spore`（behavior: `"mirror"`）

| 属性 | 值 |
|---|---|
| display_name | 镜影孢 Mirror |
| max_health | 38 |
| move_speed | 0（待机）/ 90（爆发冲刺） |
| alert_radius | 480 |
| ranged_attack | "" |
| 特殊字段 | `mirror_cache_size = 3`（缓存玩家最近移动方向数） |

**核心逻辑**：
- 每次 `_last_dir` 更新或 `Player.fire()` 被调用时，记录到 `mirror_cache`（FIFO，最多 3 条）
- 身体朝向始终跟随 `mirror_cache[-1]`（最后一条样本）
- 受到任何伤害时 `_fire_mirror_burst()`：连续射出 2 颗低硬直弹，方向 = `mirror_cache[0..1]`
- 反制：绕柱打断方向连续性、用 pierce ≥ 1 的子弹一次打穿镜像缓存刷新间隔

### 2.2 伪孢孢 `False Bloom`（behavior: `"false_bloom"`）

| 属性 | 值 |
|---|---|
| display_name | 伪孢孢 False Bloom |
| max_health | 45 |
| move_speed | 60 |
| attack_power | 6 |
| blood_color | Color(1.0, 0.55, 0.2, 1)（橙色） |

**死亡行为**：
- `_deferred_die()` 之后调用 `_spawn_false_pickup(global_position)`
- Pickup.kind = `"false"` → 视觉与真晶体完全一致但颜色泛橙红微光
- 玩家拾取后触发 `_player.take_damage(30.0)` 并 toast "⚠ 腐化结晶 — 生命 -30"
- 反制：HUD 顶部加一行"晶体来源已校验 ✓"常驻提示；或用 magnet 卡在假晶体生成前提早收走真晶体减少场上总数量

### 2.3 链结孢 `Link Sower`（behavior: `"linker"`）

| 属性 | 值 |
|---|---|
| display_name | 链结孢 Link Sower |
| max_health | 55 |
| move_speed | 55 |
| attack_power | 10 |
| special | `link_radius = 70.0`, `dmg_share_ratio = 0.5` |

**链结对系统**：
- 全局单例 `LinkSystem.gd`：`Dictionary<int, int>` 维护 `(src_id, tgt_id)` 配对
- 链结孢死亡时扫描周围 link_radius 内的活敌，优先连尚未配对的；若全部满员则随机替换一条旧链
- 受伤时：`other.get_node_or_null("Enemy").take_damage(dmg * 0.5)` （上限为其他当前 HP 的 20%）
- 链线可视化：每帧用 `RenderingServer.canvas_item_add_line` 在两个怪 global_position 间画亮金色线 + 脉动辉光
- 反制：pierce ≥ 1 可以穿透链上两只怪；或集中火力的 burst 流一次性打掉链结源

### 2.4 蚀晶孢 `Crystal Wraith`（behavior: `"wraith"`）

| 属性 | 值 |
|---|---|
| display_name | 蚀晶孢 Crystal Wraith |
| base_max_health | 50 |
| base_move_speed | 50 |
| ranged_attack | `"needle"` |
| ranged_range | 320 |
| ranged_min_range | 150 |
| spray_count | 3 |
| leaves_cloud | false |

**加速规则**：
- `_physics_process` 中每次 tick：`_crystal_boost = mini(40.0, total_crystals_on_ground × 2.5)`
- effective_speed = `base_speed + _crystal_boost`
- **抢夺晶体**：每 3s 扫描场上晶体，若 ≥ 2 颗且无 cooldown 则 `pickup.queue_free()`（直接销毁，不扣血也不给玩家 score）并发射一轮针
- 反制：故意留空场减少其加速；选 magnet 卡抢先覆盖全场磁吸

---

## 三、Boss：织理者 Loom Weavers

完整状态机见 `docs/wave3-boss-state-machine.md`。此处只列规格摘要：

| 项 | 值 |
|---|---|
| display_name | 织理者 Loom Weavers |
| behavior | `"boss"`（额外挂载 `loom_phase: int`） |
| scale_mult | 2.8 |
| contact_radius | 40 |
| charge_interval | 4.0 |
| charge_speed | 4.5（略高于原版 boss 4.2） |
| skill_interval | 5.5 |
| hp_threshold_p2 | 0.66 |
| hp_threshold_p3 | 0.33 |
| summon_stats | null（不再召唤杂兵，改 spawn 幻影） |
| clone_count(P2) | 2 |
| clone_count(P3) | 3 |
| false_crystal_density_boost(P3) | × 4 |
| mirror_spawner_rate_multiplier(P3) | × 2 |

**阶段转换钩子**：在 Enemy._process 中每帧检查 HP%：
```gdscript
if stats and not is_boss: return
var pct = health / max_health
if pct < get_meta("loom_phase", 0) == 2 and not has_meta("_p3_entered"):
    set_meta("_p3_entered", true)
    _enter_phase(3)
elif pct < 0.66 and get_meta("loom_phase", 0) < 2 and not has_meta("_p2_entered"):
    ...
```

---

## 四、技术落地清单

### 4.1 新建文件

```
scripts/enemy/Wave3Mode.gd       ← 第 3 波控制器（类似 WaveMode 但负责镜影刷怪频率、伪晶体密度、反射柱管理）
scripts/systems/LinkSystem.gd   ← 链结对单例（Dictionary<int,int>），供 Enemy._on_hit 读取
scripts/ui/CrystalVerifier.gd   ← HUD 插件节点，显示「晶体来源校验 ✓」常驻提示
assets/data/enemy_mirror.tres
assets/data/enemy_false_bloom.tres
assets/data/enemy_linker.tres
assets/data/enemy_wraith.tres
assets/data/enemy_loom.tres
scenes/world/MirrorPillar.tscn  ← 反射柱场景（Area2D + Sprite2D 蓝色脉动纹理）
scenes/world/LoomThread.tscn   ← 动态线场景（Line2D + Area2D）
tests/probe_wave3.gd            ← 单元测试：镜像缓存 / 链结分摊 / 伪晶体识别 / Boss 阶段切换
tests/shot_wave3.gd             ← 截图探针
```

### 4.2 修改现有文件

```
scripts/enemy/Enemy.gd          ← 新增 _setup_mirror() / _spawn_false_pickup() / apply_link_sharing()
scripts/enemy/EnemyStats.gd     ← 新增 mirror_cache_size / link_radius / dmg_share_ratio 等字段
scripts/world/Pickup.gd         ← 支持 kind="false" 扣血分支 + orange tint
scripts/ui/HUD.gd               ← 追加 crystal_verifier_label + chain_alert_toast
scripts/world/Arena.tscn        ← UILayer 挂 MirrorPillar（×3）+ LoomThread Pool
project.godot                   ← 注册 LinkSystem Autoload
```

### 4.3 帧动画资源（13 生物 × 2 clip × 4 帧 = 104，本次 + 5 生物 = 114）

```
assets/anim/mirror/loop      frame_00{1..4}.png
assets/anim/mirror/act1_fire frame_00{1..4}.png
assets/anim/false_bloom/loop ...
assets/anim/linker/loop      ...
assets/anim/wraith/loop      ...
assets/anim/loom/loop        ...
assets/anim/loom/act1_spin   ...
assets/anim/loom/act2_web    ...
assets/anim/loom/act3_clone  ...
assets/anim/loom/act4_rewrite...
```

### 4.4 AI 图生图流程

```bash
# 参考 assets/prompt_wave3.md，对每个 creature 发 3 次请求（loop + act + idle 变体）
node tools/gen_anim_sheets.cjs \
  --prompt-file assets/prompt_wave3.md \
  --crop-dir build/sprites_raw/wave3 \
  --output assets/characters/
godot --headless --path . --import
```

---

## 五、验收标准（DoD）

### 功能维度
- [ ] WaveMode 能在 wave3_delay 秒后自动进入 P3，且 objective_text 正确切换
- [ ] 镜影孢镜像缓存长度 ≤ 3，击中时触发 burst 且方向来自缓存历史
- [ ] 伪孢子死亡后原地生成 false pickup，玩家拾取扣血且有 toast
- [ ] 链结对系统存活期 ≥ 所有相关怪物的生命周期，消失时清理配对
- [ ] 蚀晶孢速度随场上晶体总数线性上调，抢晶体动作真实发生
- [ ] 织理者三个阶段 HP 阈值精确，进入新阶段广播 EventBus.loom_phase_changed(new_phase)

### 性能维度
- [ ] 同屏 150 敌时 P3 阶段帧率不低于 55fps（Intel UHD）
- [ ] LoomThread 动态绘制 Draw call ≤ 3/帧（使用 RenderingServer batch）
- [ ] LinkSystem 内存占用 < 2KB（Dictionary 上限按同屏敌人 150 估算）

### 测试维度
- [ ] `probe_wave3.gd` 14 断言全过
- [ ] `shot_wave3.png` 截图显示四怪同框 + Boss 处于 P2 阶段
- [ ] 导出 EXE / APK 无脚本错误，冒烟启动通过

---

## 六、实施顺序建议

```
Day 1 : 数据层 — Tres 创建 + EnemyStats 扩展字段 + 帧动画生成
Day 2 : 行为层 — Enemy.gd 四个新 hook 接入 + LinkSystem.gd
Day 3 : 规则层 — Wave3Mode.gd + MirrorPillar/LoomThread 场景
Day 4 : 反馈层 — HUD crystal_verifier + toast 文案 + 音效占位
Day 5 : 验证层 — probe_wave3.gd + shot_wave3.gd + 导出包冒烟
```

> ⚠️ 注：本规格仅描述「做什么」与「为什么」；具体 GDScript 实现细节留给开发根据现有代码规范自行展开。
