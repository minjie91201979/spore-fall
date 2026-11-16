# 《孢城 SPORE FALL》Wave 3 — AI 图生图提示词模板

> 供 `agnes-image` / `buddy-cloud.py` 批量生成 256px 透明底游戏贴图用。
> 所有提示词末尾统一加「STAY IN STYLE: cel-shaded, spore creature biomechanic, amber glowing eyes, clean thick outline, transparent background」——保证与现有 13 个生物视觉语言对齐。

---

## 通用输出规范（每次生成均需遵守）

- **分辨率**：512 × 512 px（喂给后处理脚本 `tools/make_sprites.gd` 的输入尺寸）
- **背景**：纯白 `#FFFFFF`（泛洪剔除用）
- **主体**：居中，占画面 50%~65%，无多余道具/场景元素
- **姿态**：正面站立或四分之三侧身，四肢收拢于躯干内，便于做 walk/idle 循环
- **视觉风格锚点**：孢子 + 机械骨骼混合、荧光色脉动血管、硬边赛璐璐阴影
- **禁止项**：写实皮肤/肌肉纹理、运动模糊、景深虚化、人物脸孔（非人形）

---

## 怪 1 · 镜影孢 Mirror Spore

```
A symmetrical mirror-spired fungal organism standing in a neutral idle pose, 
its body made of polished obsidian-black carapace plates with electric-blue 
circuit-like veins pulsing beneath translucent membrane seams. 

KEY FEATURES:
- Two large reflective panels on its back act as "mirrors" showing distorted player silhouettes
- Amber bioluminescent eyes that glow with cold intelligence
- No visible legs; floats 5px above ground with subtle trail particles
- Clean thick dark blue outline around silhouette edge
- Body composition: 60% black carapace / 25% translucent membrane / 15% blue circuits

STYLE ANCHOR: Keep the cel-shaded hard shadow bands typical of existing spore creatures, 
but shift color palette from green/purple towards blue-white spectrum.
```

---

## 怪 2 · 伪孢孢 False Bloom

```
A corrupted crystal-spore hybrid that looks intentionally "wrong" — like a perfect 
crystal grown inside a rotten host. It stands 40% smaller than a normal walker.

KEY FEATURES:
- Top half: pristine geometric crystal cluster in fluorescent orange and white
- Bottom half: decaying organic sack with wet texture leaking orange fluid
- One eye bulging outward on the crystal side (amber glow), other side hollow socket
- Small root-like tendrils sprouting from base but not touching ground
- Cracks along the crystal seam reveal pulsing orange light within
- Outline slightly warped at the boundary between healthy and decayed halves

STYLE ANCHOR: Same cel-shading rules but introduce an asymmetry motif never seen before 
in Waves 1-2. Orange dominates over the usual cyan/green tone.
```

---

## 怪 3 · 链结孢 Link Sower

```
A central spore core connected by visible golden energy tethers to three smaller 
floating nodules arranged in a loose triangle around it. Looks like a neural network 
made of living tissue.

KEY FEATURES:
- Core sphere in center: dark purple flesh with golden suture lines like scars
- Three satellite nodules orbit at ~15° angles, each 40% the size of core
- Golden chains/tethers connecting them are semi-transparent with inner light pulse
- All five segments have tiny amber eyes that blink out of sync
- When idle, the whole assembly slowly rotates 360° as one rigid unit
- Slight glow halo around the golden connections (outer rim effect)

STYLE ANCHOR: Emphasize connectivity and multiple-limbs without crossing into "spider". 
Color priority: gold > deep purple > amber accents. Maintain the hard-outline rule.
```

---

## 怪 4 · 蚀晶孢 Crystal Wraith

```
A tall gaunt figure composed almost entirely of jagged crystalline shards held 
together by thin strands of ghostly white mycelium. It hovers higher off ground 
than other walkers.

KEY FEATURES:
- Body built from 7-9 irregular diamond-shaped crystals in pale grey and soft white
- Each crystal facet shows internal refraction glow (faint amber bleeding through seams)
- White mycelial threads criss-cross connecting all crystal joints
- Head is a single large geode-like crystal with two sharp amber eye-slits
- Lower body trails off into diffuse smoke/particle cloud (suggests weightlessness)
- Overall posture: arms raised slightly forward like a conductor

STYLE ANCHOR: Lean heavily into the "white noise gray" spectrum mentioned in design doc. 
Make it look brittle and fragile yet dangerous if shattered. Keep same base silhouette height 
as runner (taller than brute).
```

---

## Boss · 织理者 Loom Weavers

```
A towering fungal entity combining woven fiber aesthetics with exposed mechanical loom 
parts. Think "spider meets clockmaker" — elegant, precise, unnervingly still until it moves.

SIZE & PROPORTION:
- 2.2x taller than a brute (scale_mult = 2.8 per existing convention)
- Central body is an egg-shaped sac of braided golden-orange threads
- Six long needle-like limbs extend outward symmetrically (three per side)
- Each limb tip ends in a crystalline thorn dripping faint poison

KEY FEATURES:
- Face area: smooth blank porcelain mask with two vertical amber slits for eyes
- Chest cavity: partially open revealing a spinning miniature gear-mechanism inside
- Back: large fan-like array of crystalline needles (visible during spin attack windup)
- Underbelly: layered membrane flaps that ripple when processing (idle animation reference)
- Ground interaction: no feet, hovers 20px above surface with thread-trails dangling down

COLOR PRIORITY (p1 -> p3 escalation):
- Base: fluorescent orange (#FF8C00) for main body threads
- Accents: electric blue (#00FFFF) for crystal elements  
- Warning state (p3): body turns ash-gray with cracks glowing red underneath

POSE FOR IDLE LOOP:
- Legs tucked under body like a praying mantis resting
- Front limbs slightly raised, crystal tips pointing down at 45° angle
- Central sac gently expands/contracts breathing rhythm (frame 2 compression, frame 4 extension)

STYLE ANCHOR: Must read as distinctly different from boss Brood (enemy_boss.tres). 
Brood is fleshy/pulsating; Loom Weavers should feel MECHANICAL/WOVEN. Same cel-shading 
rules, thicker bold outlines, dramatic top-down lighting creating sharp cast shadows.
```

---

## 后处理接入清单（生成完成后交给 `make_sprites.gd`）

| 文件 | 目标名 |
|---|---|
| `mirror.png` | `assets/characters/enemy_mirror.png` |
| `false_bloom.png` | `assets/characters/enemy_false_bloom.png` |
| `linker.png` | `assets/characters/enemy_linker.png` |
| `wraith.png` | `assets/characters/enemy_wraith.png` |
| `loom.png` | `assets/characters/enemy_loom.png` |

后处理步骤（自动执行，不需人工干预）：
1. 泛洪剔除与边缘连通的白色 → 保留主体内部高光
2. 主体长边归一化为 210px
3. 合成到 256 × 256 透明画布
4. 写入 `EnemyStats.sprite_texture`
