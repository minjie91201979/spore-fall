#!/usr/bin/env python3
# 把 assets/icons/ 下的 PNG 合成多尺寸 Windows ICO。
# 先跑 tools/make_icons.gd 产出各尺寸 PNG，再跑本脚本：
#   python tools/make_ico.py
# ICO 目录项宽度字段 0 表示 256；条目直接嵌 PNG 数据（Vista+ 支持）。
import struct

SIZES = [256, 128, 64, 48, 32, 16]

def main() -> None:
    blobs = []
    for s in SIZES:
        with open(f"assets/icons/icon_{s}.png", "rb") as f:
            blobs.append((s, f.read()))
    header = struct.pack("<HHH", 0, 1, len(blobs))
    entries = b""
    offset = 6 + 16 * len(blobs)
    for s, data in blobs:
        entries += struct.pack(
            "<BBBBHHII",
            0 if s >= 256 else s, 0 if s >= 256 else s,
            0, 0, 1, 32, len(data), offset,
        )
        offset += len(data)
    ico = header + entries + b"".join(d for _, d in blobs)
    with open("assets/icons/icon.ico", "wb") as f:
        f.write(ico)
    print(f"ICO_OK {len(ico)} bytes ({len(blobs)} sizes)")

if __name__ == "__main__":
    main()
