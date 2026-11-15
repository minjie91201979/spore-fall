#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
第二波贴图可读性抛光（PIL，可复现）。

背景
----
agnes 概念图是「写实深色 + 已经上好色」的图，而本作旧的 enemy_*.png 是白底程序化
简笔贴图，靠 EnemyStats.tint 相乘染色区分变种。把写实深图再乘一个深紫 tint 会糊成
一坨黑紫；且 Enemy.tscn 的运行时描边是深黑色，在暗地面上等于没有轮廓，低画质档
还会被 Quality 整个关掉。

对策（不改运行时代码，零回归风险）
----------------------------------
1) 提亮暗部：gamma 校正，把 avgLum ~50 抬到 ~100，同时保住青绿荧光高光；
2) 把「主题色亮轮廓」烘焙进 PNG 自身 —— 不依赖运行时描边，任何画质档都可见；
3) 4 个新 .tres 的 tint 改为近白，让写实概念图的本色完整透出（见各 .tres）。

顺序（重要）
------------
    tools/gen_wave2.cjs        -> build/sprites_raw/*.png      概念原图
    tools/make_sprites.gd      -> assets/characters/*.png      去白底 + 归一化
    tools/polish_wave2_sprites.py -> 覆写上面 4 张            提亮 + 烘焙亮轮廓  <- 本脚本
    Godot --headless --import                                  刷新贴图导入缓存
重跑 make_sprites.gd 会冲掉本脚本效果，之后必须再跑一次本脚本。

用法: python tools/polish_wave2_sprites.py [--gamma 0.62] [--dry]
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "characters"
BEFORE_DIR = ROOT / "docs" / "art"

# 每只怪的发光轮廓色（与 docs/wave2_design.html 的设定色板一致）
# 第三项是 gamma：原图越暗提得越狠；绽孢本就荧光高亮，只轻微抬一点避免过曝。
JOBS = {
    "enemy_corroder.png": (0xD8, 0xE2, 0x5A, 0.66),  # 酸蚀黄绿
    "enemy_burrower.png": (0xC9, 0xA0, 0xFF, 0.56),  # 亮紫
    "enemy_bloom.png":    (0x7D, 0xFF, 0xA8, 0.86),  # 荧光绿
    "enemy_abyss.png":    (0x6E, 0xF2, 0xC4, 0.54),  # 深渊青绿
}


def lift_dark(img: Image.Image, gamma: float) -> Image.Image:
    """只提亮 RGB，alpha 原样保留；gamma<1 抬暗部且高光不易过曝。"""
    rgba = img.convert("RGBA")
    r, g, b, a = rgba.split()
    lut = [min(255, round(255 * (i / 255.0) ** gamma)) for i in range(256)]
    rgb = Image.merge("RGB", (r.point(lut), g.point(lut), b.point(lut)))
    return Image.merge("RGBA", (*rgb.split(), a))


def bake_rim(img: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    """把一圈主题色亮轮廓烘焙进贴图：膨胀 alpha 求外环，底层铺色，再把主体盖回去。"""
    alpha = img.getchannel("A")

    # 内层实边 + 外层柔光，两层都只作用在透明背景上
    inner = alpha.filter(ImageFilter.MaxFilter(9))
    outer = alpha.filter(ImageFilter.MaxFilter(17)).filter(ImageFilter.GaussianBlur(2.2))

    rim_hard = Image.new("RGBA", img.size, (*color, 0))
    rim_hard.putalpha(Image.eval(
        Image.fromarray(_sub_alpha(inner, alpha)), lambda v: min(210, v)))
    glow = Image.new("RGBA", img.size, (*color, 0))
    glow.putalpha(Image.eval(
        Image.fromarray(_sub_alpha(outer, alpha)), lambda v: int(v * 0.42)))

    out = Image.alpha_composite(glow, rim_hard)
    return Image.alpha_composite(out, img)


def _sub_alpha(a: Image.Image, b: Image.Image):
    """max(a-b, 0)，用 numpy 更省事；无 numpy 时退回纯 PIL 的 ImageChops。"""
    try:
        import numpy as np
        d = np.asarray(a, dtype=np.int16) - np.asarray(b, dtype=np.int16)
        return np.clip(d, 0, 255).astype("uint8")
    except ImportError:
        from PIL import ImageChops
        return ImageChops.subtract(a, b)


def stats(img: Image.Image) -> tuple[float, float]:
    """非透明像素的平均亮度 / 近黑占比，用于量化抛光效果。"""
    import numpy as np
    arr = np.asarray(img.convert("RGBA"))
    m = arr[..., 3] > 128
    if not m.any():
        return 0.0, 0.0
    px = arr[..., :3][m].astype(float)
    lum = px[..., 0] * 0.299 + px[..., 1] * 0.587 + px[..., 2] * 0.114
    return float(lum.mean()), float((lum < 60).mean() * 100)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gamma", type=float, default=0.0,
                    help=">0 时覆盖每只怪的自适应 gamma")
    ap.add_argument("--dry", action="store_true", help="只打印指标，不写文件")
    args = ap.parse_args()

    BEFORE_DIR.mkdir(parents=True, exist_ok=True)
    for name, (r, g, b, gamma) in JOBS.items():
        color = (r, g, b)
        gamma = args.gamma if args.gamma > 0 else gamma
        path = SPRITES / name
        if not path.exists():
            print(f"MISS {name}")
            continue
        original = Image.open(path).convert("RGBA")
        before_lum, before_dark = stats(original)

        polished = bake_rim(lift_dark(original, gamma), color)
        after_lum, after_dark = stats(polished)

        if not args.dry:
            # 抛光前的副本留作 before/after 对比证据（首次运行才备份，避免二次抛光把它覆盖）
            before_path = BEFORE_DIR / f"sprite_before_{name}"
            if not before_path.exists():
                shutil.copy2(path, before_path)
            polished.save(path, "PNG", optimize=True)

        print(f"{name:24s} lum {before_lum:5.1f} -> {after_lum:5.1f}   "
              f"dark {before_dark:4.1f}% -> {after_dark:4.1f}%"
              f"{'  [DRY]' if args.dry else ''}")
    print("DONE")


if __name__ == "__main__":
    main()
