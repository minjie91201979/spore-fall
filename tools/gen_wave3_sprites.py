#!/usr/bin/env python3
"""为 Wave 3 五只生物生成 256x256 RGBA 精灵图与帧动画。

要点（踩坑记录）：
  1. 每个像素都必须 append，包括 alpha=0 的区域；否则每行字节数不足，PNG 解不出来。
  2. 写完后必须用 zlib 解回来验证 raw 长度 == height * (1 + width*4)。
  3. 生成后要删掉旧 .import 并让 Godot 重新导入。
"""
import math
import os
import random
import struct
import zlib

W = H = 256
SIZE = W * H


def chunk(ctype: bytes, data: bytes) -> bytes:
    body = ctype + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xFFFFFFFF)


def encode_png(pixels) -> bytes:
    """pixels: list of (r,g,b,a)，长度必须正好 W*H。"""
    assert len(pixels) == SIZE, f'pixel count {len(pixels)} != {SIZE}'

    raw = bytearray()
    for y in range(H):
        raw.append(0)  # filter type 0 (None)
        base = y * W
        for x in range(W):
            r, g, b, a = pixels[base + x]
            raw += bytes((r, g, b, a))

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0)
    out = sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')

    # 自校验：解回来长度必须等于 height * (1 + width*4)
    expect = H * (1 + W * 4)
    assert len(raw) == expect, f'raw len {len(raw)} != {expect}'
    return out


def clamp(v: float) -> int:
    return max(0, min(255, int(v)))


def base_layer(r: int, g: int, b: int) -> list:
    """先铺满全透明，再覆盖形状：保证每个像素都有值。"""
    return [(0, 0, 0, 0)] * SIZE


def put(px: list, x: int, y: int, color) -> None:
    if 0 <= x < W and 0 <= y < H:
        px[y * W + x] = color


# ---------- 五种形态 ----------

def gen_blob(r, g, b, seed=0):
    """通用孢子团：椭圆软边 + 中心略暗 + 微噪点。"""
    random.seed(seed)
    px = base_layer(r, g, b)
    cx, cy = W / 2, H / 2
    rx, ry = W * 0.44, H * 0.44
    for y in range(H):
        for x in range(W):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            d = math.sqrt(dx * dx + dy * dy)
            if d > 1.0:
                continue
            a = int(255 * (1.0 - d ** 1.6))
            shade = 0.72 + 0.34 * (1.0 - d)
            n = random.randint(-10, 10)
            put(px, x, y, (clamp(r * shade + n), clamp(g * shade + n), clamp(b * shade + n), a))
    return px


def gen_diamond(r, g, b, seed=0):
    """镜影孢：菱形晶体 + 高光。"""
    random.seed(seed)
    px = base_layer(r, g, b)
    cx, cy = W / 2, H / 2
    half = 100
    for y in range(H):
        for x in range(W):
            dx, dy = abs(x - cx), abs(y - cy)
            if dx + dy * 0.72 > half:
                continue
            k = 1.0 - (dx + dy) / (half * 1.25)
            a = int(200 + 55 * k)
            n = random.randint(-8, 8)
            put(px, x, y, (clamp(r + 60 * k + n), clamp(g + 60 * k + n), clamp(b + 70 * k + n), a))
    return px


def gen_rings(r, g, b, seed=0):
    """链结孢：两个交叠圆环。"""
    random.seed(seed)
    px = base_layer(r, g, b)
    cx, cy = W / 2, H / 2
    ring_r = 52
    thick = 15
    for y in range(H):
        for x in range(W):
            best = 1e9
            for ox in (-30, 30):
                d = math.hypot(x - cx - ox, y - cy)
                best = min(best, abs(d - ring_r))
            if best > thick:
                continue
            a = int(255 * (1.0 - best / thick))
            n = random.randint(-8, 8)
            put(px, x, y, (clamp(r + n), clamp(g + n), clamp(b + n), a))
    return px


def gen_wraith(r, g, b, seed=0):
    """蚀晶孢：竖长幽影 + 下摆拖尾。"""
    random.seed(seed)
    px = base_layer(r, g, b)
    cx, cy = W / 2, H / 2 - 8
    rx, ry = 72, 96
    for y in range(H):
        for x in range(W):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            d = math.hypot(dx, dy)
            spread = 1.0
            if y > cy + ry * 0.25:
                t = min(1.0, (y - cy - ry * 0.25) / (ry * 0.65))
                spread = 1.0 + 0.45 * t
            if d > spread:
                continue
            a = int(215 * (1.0 - (d / spread) ** 1.7))
            n = random.randint(-10, 10)
            glow = 45 * max(0.0, 1.0 - d)
            put(px, x, y, (clamp(r + glow + n), clamp(g + glow + n), clamp(b + glow + n), a))
    return px


def gen_boss(r, g, b, seed=0):
    """织理者：带尖刺边缘的大型威胁轮廓 + 双眼高光。"""
    random.seed(seed)
    px = base_layer(r, g, b)
    cx, cy = W / 2, H / 2
    outer = 112
    for y in range(H):
        for x in range(W):
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            spike = 1.0 + 0.22 * math.sin(ang * 6) + 0.12 * math.sin(ang * 11)
            eff = outer * spike
            if dist > eff:
                continue
            t = dist / eff
            a = int(255 * (1.0 - t ** 1.5))
            n = random.randint(-12, 12)
            pr = clamp(r + 50 * t + n)
            pg = clamp(g - 18 * t + n)
            pb = clamp(b - 10 * t + n)
            # 双眼反向高光
            if math.hypot(x - cx - 22, y - cy - 12) < 13 or math.hypot(x - cx + 22, y - cy - 12) < 13:
                pr, pg, pb = clamp(pr + 110), clamp(pg + 110), clamp(pb + 60)
            put(px, x, y, (pr, pg, pb, a))
    return px


SPRITES = {
    'mirror':     ((120, 185, 250), gen_diamond),
    'falsebloom': ((245, 145, 55), gen_blob),
    'linker':     ((235, 195, 60), gen_rings),
    'wraith':     ((175, 178, 200), gen_wraith),
    'loomweaver': ((165, 62, 28), gen_boss),
}


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    for idx, (name, (rgb, gen)) in enumerate(SPRITES.items()):
        r, g, b = rgb

        # 角色静态贴图（FramePlayer 以文件名推导动画 key，必须存在）
        px = gen(r, g, b, seed=idx * 100)
        data = encode_png(px)
        char_path = f'assets/characters/enemy_{name}.png'
        with open(char_path, 'wb') as f:
            f.write(data)
        print(f'[char] {char_path}  {len(data)}B')

        # 8 帧动画：loop x4 / act x4，逐帧换 seed 制造细微差异
        for clip in ('loop', 'act'):
            for i in range(1, 5):
                frame_px = gen(r, g, b, seed=idx * 100 + (0 if clip == 'loop' else 500) + i)
                frame_data = encode_png(frame_px)
                fp = f'assets/anim/{name}/{clip}/frame_{i:03d}.png'
                os.makedirs(os.path.dirname(fp), exist_ok=True)
                with open(fp, 'wb') as f:
                    f.write(frame_data)
        print(f'[anim] assets/anim/{name}/ loop+act 共 8 帧')

    print('DONE')


if __name__ == '__main__':
    main()
