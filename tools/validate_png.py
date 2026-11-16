#!/usr/bin/env python3
"""PNG 完整性校验器：解 IDAT，按 IHDR 校验每行字节数。

用途：本仓库的手写 PNG 生成器曾因少 append 像素产出坏文件，
Godot 导入时静默 valid=false，最终让整条 preload 链崩塌。
"""
import glob
import struct
import sys
import zlib


def validate(path: str) -> tuple[bool, str]:
    with open(path, 'rb') as f:
        data = f.read()

    if data[:8] != b'\x89PNG\r\n\x1a\n':
        return False, 'bad signature'

    pos = 8
    ihdr = None
    idat = bytearray()
    while pos < len(data):
        if pos + 8 > len(data):
            return False, 'truncated chunk header'
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if len(body) != length:
            return False, f'truncated {ctype}'
        crc_got = struct.unpack('>I', data[pos + 8 + length:pos + 12 + length])[0]
        crc_exp = zlib.crc32(ctype + body) & 0xFFFFFFFF
        if crc_got != crc_exp:
            return False, f'CRC mismatch on {ctype}'
        if ctype == b'IHDR':
            ihdr = body
        elif ctype == b'IDAT':
            idat += body
        elif ctype == b'IEND':
            break
        pos += 12 + length

    if ihdr is None:
        return False, 'no IHDR'
    w, h, depth, ctype_, _, _, interlace = struct.unpack('>IIBBBBB', ihdr)
    if depth != 8 or ctype_ != 6:
        return False, f'unsupported depth={depth} colortype={ctype_}'
    if interlace != 0:
        return False, 'interlaced not supported'

    try:
        raw = zlib.decompress(bytes(idat))
    except zlib.error as e:
        return False, f'zlib: {e}'

    expect = h * (1 + w * 4)
    if len(raw) != expect:
        return False, f'raw {len(raw)} != {expect}'
    return True, f'{w}x{h} RGBA ok'


if __name__ == '__main__':
    patterns = sys.argv[1:] or ['assets/characters/enemy_*.png', 'assets/anim/*/*/*.png']
    bad = 0
    total = 0
    for pat in patterns:
        for p in sorted(glob.glob(pat)):
            if any(k in p for k in ('enemy_boss', 'enemy_abyss')) and 'characters' in p:
                pass
            total += 1
            ok, msg = validate(p)
            if not ok:
                bad += 1
                print(f'BAD  {p}: {msg}')
    print(f'\nchecked={total} bad={bad}')
    sys.exit(1 if bad else 0)
