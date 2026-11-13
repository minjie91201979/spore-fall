#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成武器像素图标（assets/ui/wpn_*.png）。
12x12 逻辑网格、8px 像素块 -> 96x96 透明底 PNG。
只用矩形/像素块拼装，风格与项目的极简色块美术一致；重跑幂等。
用法: python tools/gen_weapon_icons.py [assets/ui]
"""
import sys
import os
from PIL import Image, ImageDraw

PX = 8           # 每格像素
GRID = 12        # 逻辑网格边长
SIZE = PX * GRID

# 调色板（与游戏色块美术同族）
K = (35, 39, 46, 255)      # 近黑描边
D = (71, 80, 90, 255)      # 深金属
M = (154, 164, 174, 255)   # 金属
W = (138, 90, 51, 255)     # 木
Wo = (168, 113, 63, 255)   # 浅木
O = (255, 140, 58, 255)    # 橙（火）
Od = (255, 90, 31, 255)    # 深橙
C = (69, 224, 255, 255)    # 青（激光）
Cd = (24, 153, 201, 255)   # 深青
G = (255, 207, 90, 255)    # 金
Gd = (201, 150, 42, 255)   # 暗金


def R(d, x0, y0, x1, y1, color):
    """闭区间逻辑格矩形（像素对齐）"""
    d.rectangle([x0 * PX, y0 * PX, (x1 + 1) * PX - 1, (y1 + 1) * PX - 1], fill=color)


def P(d, x, y, color):
    R(d, x, y, x, y, color)


def deagle(d):
    R(d, 3, 4, 11, 6, M)          # 枪身滑套
    R(d, 3, 3, 11, 4, D)          # 滑套顶棱
    R(d, 3, 6, 9, 7, D)           # 下机匣
    R(d, 3, 7, 5, 11, K)          # 握把
    R(d, 3, 7, 4, 11, D)
    P(d, 6, 8, K)                 # 扳机
    R(d, 11, 4, 11, 6, G)         # 金色枪口
    P(d, 12, 5, G)                # 枪口星


def shotgun(d):
    R(d, 2, 4, 11, 5, D)          # 枪管
    R(d, 2, 5, 11, 6, M)          # 弹仓管
    R(d, 5, 6, 8, 8, W)           # 护木
    R(d, 0, 5, 2, 9, Wo)          # 枪托
    R(d, 10, 4, 11, 5, Gd)        # 金色箍带
    P(d, 12, 4, K)                # 枪口
    P(d, 12, 5, K)


def firerifle(d):
    R(d, 1, 4, 10, 6, M)          # 机匣
    R(d, 0, 5, 1, 8, D)           # 枪托
    R(d, 3, 2, 7, 3, D)           # 瞄具
    P(d, 7, 2, C)                 # 瞄具镜头
    R(d, 5, 6, 7, 10, O)          # 橙色弹匣（火弹）
    R(d, 10, 4, 11, 5, D)         # 枪管
    R(d, 11, 3, 12, 4, Od)        # 枪口火光
    P(d, 12, 4, O)


def flamethrower(d):
    R(d, 1, 4, 4, 9, D)           # 燃料罐
    R(d, 1, 6, 4, 7, Od)          # 罐身橙警示条
    R(d, 4, 5, 9, 6, M)           # 输料管
    R(d, 9, 5, 11, 6, G)          # 喷嘴
    R(d, 11, 3, 12, 4, O)         # 喷出的火焰
    R(d, 11, 7, 12, 8, Od)
    P(d, 12, 5, O)
    P(d, 12, 6, O)


def laser(d):
    R(d, 1, 5, 9, 7, D)           # 机身
    R(d, 2, 4, 8, 4, C)           # 顶部导轨（青）
    R(d, 3, 7, 5, 11, K)          # 握把
    R(d, 3, 7, 4, 11, D)
    R(d, 9, 5, 11, 6, Cd)         # 聚能枪管
    R(d, 11, 4, 12, 7, C)         # 枪口辉光
    P(d, 12, 5, (200, 245, 255, 255))
    P(d, 12, 6, (200, 245, 255, 255))


WEAPONS = {
    "wpn_deagle": deagle,
    "wpn_shotgun": shotgun,
    "wpn_firerifle": firerifle,
    "wpn_flamethrower": flamethrower,
    "wpn_laser": laser,
}


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "assets/ui"
    os.makedirs(outdir, exist_ok=True)
    for name, fn in WEAPONS.items():
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        fn(d)
        path = os.path.join(outdir, name + ".png")
        img.save(path)
        print("saved", path)


if __name__ == "__main__":
    main()
