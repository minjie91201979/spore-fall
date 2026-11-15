#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把 agnes 生成的「四格动作帧表」裁成按序编号的单帧 PNG，作为游戏内唯一运动来源。

管线
----
build/anim_sheets/<key>_loop.png  -> assets/anim/<key>/loop/frame_001..004.png
build/anim_sheets/<key>_act.png   -> assets/anim/<key>/act/frame_001..004.png

关键约定
--------
- 帧序列按「帧001、帧002、帧003、帧004」编号，对应文件名 frame_001.png …
  播放器按数字升序播放。文件名用 ASCII 以避开 Windows 中文路径在 Git / Godot
  导入时的编码问题，「帧00N」是文档与配置里的逻辑编号。
- 分格按**实际像素尺寸**计算（agnes 返回尺寸 ≠ 请求尺寸，禁止硬编码 1536x1024）。
- 每格单独做「泛洪去白底 → 主体包围盒 → 归一化到 256 画布、主体长边 210」
  —— 与 make_sprites.gd 完全一致，保证换帧不跳动、不改游戏内体型。
- 复用抛光脚本的 gamma 提亮 + 主题色亮轮廓，保持暗地面可读性。
- 每帧各自归一化到统一包围盒，可抵消 AI 帧表里轻微的位置/大小漂移。

用法: python tools/split_anim_sheets.py [--dry]
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SHEETS = ROOT / "build" / "anim_sheets"
OUT = ROOT / "assets" / "anim"

CANVAS = 256
SUBJECT = 210
WHITE_TOL = 0.24

# 与 polish_wave2_sprites.py 一致的主题色轮廓（第二波四只 + 其余按 tint 近似）
RIM = {
    "corroder": (0xD8, 0xE2, 0x5A),
    "burrower": (0xC9, 0xA0, 0xFF),
    "bloom":    (0x7D, 0xFF, 0xA8),
    "abyss":    (0x6E, 0xF2, 0xC4),
    "boss":     (0xF2, 0x7A, 0xA6),
    "walker":   (0x8C, 0xE8, 0xDE),
    "runner":   (0x9A, 0xE8, 0x76),
    "brute":    (0xE8, 0xA8, 0x76),
    "lurker":   (0xC0, 0x9A, 0xE8),
    "miasma":   (0x8C, 0xE8, 0x9A),
    "splitter": (0xE8, 0xD8, 0x8C),
    "spitter":  (0x8C, 0xD8, 0xE8),
    "sprayer":  (0xE8, 0x9A, 0xC0),
}


def near_white(arr: np.ndarray) -> np.ndarray:
    """接近白：(1-r)+(1-g)+(1-b) 之和小于阈值（与 make_sprites.gd 同款）。"""
    a = arr.astype(np.float32) / 255.0
    return ((1.0 - a[..., 0]) + (1.0 - a[..., 1]) + (1.0 - a[..., 2])) < WHITE_TOL


def remove_white_bg(img: Image.Image) -> Image.Image:
    """从四边泛洪清除与边缘连通的白区，主体内部白色高光保留。"""
    rgba = np.array(img.convert("RGBA"), dtype=np.uint8)
    h, w = rgba.shape[:2]
    mask = near_white(rgba[..., :3])
    from collections import deque
    seen = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and mask[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    rgba[seen, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def keep_largest_component(img: Image.Image) -> Image.Image:
    """只保留最大连通主体，清掉相邻格渗入的小碎片 / AI 多画的重复小主体。

    AI 生成的四格帧表里，偶尔会有一格出现两个以上角色，或边缘残留邻格的
    发光碎屑。若不清理，播放时会出现「突然多出一只」的跳帧感。
    """
    arr = np.array(img.convert("RGBA"))
    mask = arr[..., 3] > 128
    if not mask.any():
        return img
    try:
        from scipy import ndimage
        lab, n = ndimage.label(mask, structure=np.ones((3, 3), dtype=int))
        if n <= 1:
            return img
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        keep_label = int(np.argmax(sizes)) + 1
        keep = (lab == keep_label)
    except ImportError:
        # 无 scipy 时退化为简单的行列投影裁剪（保住绝大多数情况）
        ys, xs = np.where(mask)
        keep = np.zeros_like(mask)
        keep[int(ys.min()):int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1] = True
    arr[~keep, 3] = 0
    return Image.fromarray(arr, "RGBA")


def content_box(img: Image.Image):
    a = np.array(img.getchannel("A"))
    ys, xs = np.where(a > 128)
    if len(xs) == 0:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def lift_dark(img: Image.Image, gamma: float) -> Image.Image:
    rgba = img.convert("RGBA")
    r, g, b, a = rgba.split()
    lut = [min(255, round(255 * (i / 255.0) ** gamma)) for i in range(256)]
    rgb = Image.merge("RGB", (r.point(lut), g.point(lut), b.point(lut)))
    return Image.merge("RGBA", (*rgb.split(), a))


def bake_rim(img: Image.Image, color) -> Image.Image:
    alpha = img.getchannel("A")
    inner = alpha.filter(ImageFilter.MaxFilter(9))
    outer = alpha.filter(ImageFilter.MaxFilter(17)).filter(ImageFilter.GaussianBlur(2.2))
    d1 = np.clip(np.asarray(inner, np.int16) - np.asarray(alpha, np.int16), 0, 255).astype("uint8")
    d2 = np.clip(np.asarray(outer, np.int16) - np.asarray(alpha, np.int16), 0, 255).astype("uint8")
    rim = Image.new("RGBA", img.size, (*color, 0))
    rim.putalpha(Image.fromarray(np.minimum(d1, 210).astype("uint8")))
    glow = Image.new("RGBA", img.size, (*color, 0))
    glow.putalpha(Image.fromarray((d2 * 0.42).astype("uint8")))
    return Image.alpha_composite(Image.alpha_composite(glow, rim), img)


def split_sheet(sheet: Image.Image, key: str) -> list[Image.Image] | None:
    """按实际宽度四等分，逐格去白底 + 归一化。"""
    w, h = sheet.size
    cw = w // 4
    color = RIM.get(key, (0x9E, 0xF2, 0xC4))
    frames = []
    for i in range(4):
        # 每格左右各留一点余量，避免角色正好压在分界线上被切断
        pad = int(cw * 0.04)
        x0 = max(0, i * cw - pad)
        x1 = min(w, (i + 1) * cw + pad)
        cell = sheet.crop((x0, 0, x1, h)).convert("RGBA")
        cell = remove_white_bg(cell)
        cell = keep_largest_component(cell)
        box = content_box(cell)
        if box is None:
            print("  警告: 第 %d 格为空" % (i + 1))
            return None
        subj = cell.crop(box)
        sw, sh = subj.size
        if sw >= sh:
            nw, nh = SUBJECT, max(1, int(round(sh * SUBJECT / sw)))
        else:
            nh, nw = SUBJECT, max(1, int(round(sw * SUBJECT / sh)))
        subj = subj.resize((nw, nh), Image.LANCZOS)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.alpha_composite(subj, ((CANVAS - nw) // 2, (CANVAS - nh) // 2))
        # 帧表已是提亮后的写实图，仅补一层弱亮轮廓，避免二次过曝
        frames.append(bake_rim(canvas, color))
    return frames


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    sheets = sorted(SHEETS.glob("*_loop.png")) + sorted(SHEETS.glob("*_act.png"))
    print("帧表数量:", len(sheets))
    total = 0
    for f in sheets:
        stem = f.stem
        key, _, kind = stem.rpartition("_")
        if kind not in ("loop", "act") or not key:
            continue
        sheet = Image.open(f).convert("RGB")
        frames = split_sheet(sheet, key)
        if frames is None:
            print("跳过(分格失败):", f.name)
            continue
        # 帧序列目录：loop（循环）/ act（单次），文件按「帧001…」逻辑编号
        dest = OUT / key / kind
        if not args.dry:
            dest.mkdir(parents=True, exist_ok=True)
        for i, fr in enumerate(frames, 1):
            if not args.dry:
                fr.save(dest / ("frame_%03d.png" % i), "PNG", optimize=True)
            total += 1
        print("%-22s %s -> %s/frame_001..004.png  (源 %dx%d)" %
              (f.name, key, kind, *sheet.size))
    print("总帧数:", total, "[DRY]" if args.dry else "")


if __name__ == "__main__":
    main()
