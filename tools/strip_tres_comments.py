#!/usr/bin/env python3
"""清理 .tres 里的行尾注释。

Godot 的文本资源解析器**不支持行尾 `#` 注释**：
    move_speed = 0.0   # 说明
下一行的属性会被吞掉，静默回落到脚本默认值（不报错！）。
本脚本只删「值后面紧跟 #」的尾巴，整行注释保持不动。
"""
import glob
import re
import sys

# 值后面 空白 + # 到行尾
TRAILING = re.compile(r'^(?P<lhs>\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*.+?)\s+#.*$')


def clean(path: str) -> int:
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines()

    removed = 0
    out = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith('#') or stripped.startswith(';'):
            out.append(line)
            continue
        m = TRAILING.match(line)
        if m:
            out.append(m.group('lhs').rstrip())
            removed += 1
        else:
            out.append(line)

    if removed:
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(out) + '\n')
    return removed


if __name__ == '__main__':
    patterns = sys.argv[1:] or ['assets/data/*.tres']
    total = 0
    for pat in patterns:
        for p in sorted(glob.glob(pat)):
            n = clean(p)
            if n:
                print(f'{p}: 清理 {n} 处行尾注释')
                total += n
    print(f'共清理 {total} 处')
