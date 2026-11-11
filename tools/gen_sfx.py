# 程序化生成游戏音效（16-bit mono 22050Hz wav）。
# 用法: python gen_sfx.py <输出目录>
import numpy as np
import wave
import sys

SR = 22050
outdir = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"

def save(name, samples, outdir):
    samples = np.clip(samples, -1.0, 1.0)
    data = (samples * 32767).astype(np.int16)
    with wave.open(f"{outdir}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(samples)/SR:.2f}s")

def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR * decay)

def noise(n, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, n)

# 开火：短促气枪声 = 高频噪声爆 + 快衰减
n = int(SR * 0.09)
x = noise(n, 1) * env_exp(n, 60) + 0.5 * noise(n, 2) * env_exp(n, 200)
save("shoot", x * 0.5, outdir)

# 命中：闷击 = 低频正弦衰减 + 少量噪声
n = int(SR * 0.12)
t = np.arange(n) / SR
x = np.sin(2 * np.pi * 180 * t) * env_exp(n, 40) + 0.2 * noise(n, 3) * env_exp(n, 70)
save("hit", x * 0.6, outdir)

# 击杀：爆裂 = 噪声轰 + 低频扫频下坠
n = int(SR * 0.4)
t = np.arange(n) / SR
f = 220 * np.exp(-t * 6) + 60
phase = 2 * np.pi * np.cumsum(f) / SR
x = noise(n, 4) * env_exp(n, 12) + 0.6 * np.sin(phase) * env_exp(n, 10)
save("kill", x * 0.7, outdir)

# 受伤：低吼 = 锯齿波下滑 + 颤音
n = int(SR * 0.3)
t = np.arange(n) / SR
f = 150 * np.exp(-t * 3) + 70
vib = 1 + 0.04 * np.sin(2 * np.pi * 30 * t)
phase = 2 * np.pi * np.cumsum(f * vib) / SR
saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
x = saw * env_exp(n, 14) + 0.15 * noise(n, 5) * env_exp(n, 30)
save("hurt", x * 0.55, outdir)

# 拾取：上行双音 blip（660Hz → 990Hz，清脆悦耳）
n = int(SR * 0.16)
t = np.arange(n) / SR
f = np.where(t < 0.08, 660.0, 990.0)
phase = 2 * np.pi * np.cumsum(f) / SR
x = 0.5 * np.sin(phase) + 0.15 * np.sign(np.sin(phase))  # 正弦为主 + 少量方波提亮
x *= env_exp(n, 16)
save("pickup", x * 0.55, outdir)

# 升级：上行三连音琶音（C5-E5-G5，清脆确认感）
n = int(SR * 0.45)
t = np.arange(n) / SR
x = np.zeros(n)
for i, f in enumerate([523.25, 659.25, 783.99]):
    seg0 = int(SR * 0.12 * i)
    seg_n = n - seg0
    tt = t[:seg_n]
    x[seg0:] += 0.5 * np.sin(2 * np.pi * f * tt) * env_exp(seg_n, 10)
save("levelup", x * 0.6, outdir)

# BGM 循环（16s 暗黑氛围垫底）：频率取 16s 整周期数，保证无缝循环
LOOP = 16.0
n = int(SR * LOOP)
t = np.arange(n) / SR
x = np.zeros(n)
for k, amp in [(880, 0.16), (1320, 0.10), (1760, 0.07)]:  # 55Hz / 82.5Hz / 110Hz
    lfo = 0.7 + 0.3 * np.sin(2 * np.pi * (k / LOOP) * t / 16)  # 缓慢起伏（同样整周期）
    x += amp * np.sin(2 * np.pi * k / LOOP * t) * lfo
# 心跳脉冲（60bpm，整周期内整数拍）
beat_t = np.floor(t * 1.0)  # 每秒 1 拍
beat_phase = (t * 1.0) % 1.0
beat = (beat_phase < 0.06).astype(float) * 0.35 + ((beat_phase > 0.2) & (beat_phase < 0.26)).astype(float) * 0.25
x += np.sin(2 * np.pi * 48 * t) * beat
x *= 0.9
save("bgm_loop", x, outdir)
