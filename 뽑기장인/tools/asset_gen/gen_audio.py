"""뽑기방 효과음·배경음악 합성 (모두 직접 합성한 오리지널 사운드)."""
import os
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
SR = 44100
rng = np.random.default_rng(11)


def t(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(n, a=0.005, d=0.1, sr=SR):
    x = np.arange(n) / sr
    e = np.minimum(1, x / max(a, 1e-4)) * np.exp(-np.maximum(x - a, 0) / max(d, 1e-4))
    return e


def lowpass(x, cutoff, sr=SR):
    a = np.exp(-2 * np.pi * cutoff / sr)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff, sr=SR):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def bp_fast(x, lo, hi, sr=SR):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    m = (f >= lo) & (f <= hi)
    X *= m
    return np.fft.irfft(X, len(x))


def save(name, x, sr=SR, peak=0.85):
    os.makedirs(OUT, exist_ok=True)
    x = np.asarray(x, float)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    print("saved", name, f"{len(x) / sr:.2f}s")


def click(dur=0.03, freq=3000, decay=0.006):
    n = int(dur * SR)
    noise = rng.standard_normal(n)
    tone = np.sin(2 * np.pi * freq * t(dur))
    return (noise * 0.6 + tone * 0.5) * env(n, 0.0005, decay)


def clunk(dur=0.25, f0=110, decay=0.05):
    n = int(dur * SR)
    x = t(dur)
    body = np.sin(2 * np.pi * f0 * x) * env(n, 0.001, decay)
    body += 0.5 * np.sin(2 * np.pi * f0 * 2.7 * x) * env(n, 0.001, decay * 0.5)
    nz = lp_fast(rng.standard_normal(n), 2500) * env(n, 0.0005, 0.012)
    return body + nz * 1.5


def motor(dur, f=95, whine=780, rough=0.3):
    x = t(dur)
    n = len(x)
    s = 0.6 * np.sign(np.sin(2 * np.pi * f * x)) * 0.3 + 0.5 * np.sin(2 * np.pi * f * x)
    s += 0.25 * np.sin(2 * np.pi * f * 2 * x) + 0.12 * np.sin(2 * np.pi * whine * x)
    s += rough * lp_fast(rng.standard_normal(n), 1800)
    s *= 1 + 0.15 * np.sin(2 * np.pi * 7 * x)
    return lp_fast(s, 3000)


def make_loop(x, fade=0.05):
    """앞뒤를 크로스페이드해 이음매 없는 루프로."""
    n = int(fade * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def sfx():
    # 지폐 투입: 빨려 들어가는 모터 소리 + 덜컥
    d = 1.0
    x = t(d)
    m = motor(d, f=140, whine=1300, rough=0.4) * np.clip(np.minimum(x / 0.05, (d - x) / 0.1), 0, 1)
    sweep = 0.3 * np.sin(2 * np.pi * (300 + 500 * x) * x) * env(len(x), 0.05, 0.6)
    out = m * 0.7 + sweep
    ck = clunk(0.25, 140, 0.04)
    out[int(0.85 * SR):int(0.85 * SR) + len(ck)] += ck[:len(out) - int(0.85 * SR)] * 1.2
    save("bill_insert", out)

    # 크레딧 띵동
    x = t(0.5)
    a = np.sin(2 * np.pi * 1318 * x) * env(len(x), 0.002, 0.12)
    b = np.zeros_like(a)
    k = int(0.12 * SR)
    b[k:] = np.sin(2 * np.pi * 1760 * x[:-k]) * env(len(x) - k, 0.002, 0.18)
    save("credit", a + b)

    # 동전
    x = t(0.6)
    s = sum(np.sin(2 * np.pi * f * x) * env(len(x), 0.001, dd) for f, dd in ((2700, 0.25), (4100, 0.15), (6300, 0.08)))
    save("coin", s + click(0.6, 5000, 0.004))

    save("button", clunk(0.12, 400, 0.02) + click(0.12, 2500, 0.004))
    save("joystick", clunk(0.08, 220, 0.015) * 0.6 + click(0.08, 1800, 0.003) * 0.4)

    # 레일 이동 모터 루프 / 와인치(줄 감는) 루프
    save("motor_loop", make_loop(motor(1.6, f=92, whine=760, rough=0.25)), peak=0.6)
    save("winch_loop", make_loop(motor(1.6, f=130, whine=1450, rough=0.18)), peak=0.6)

    # 솔레노이드(집게) 철컥
    x = t(0.3)
    sol = clunk(0.3, 180, 0.03) + 0.6 * np.sin(2 * np.pi * 2300 * x) * env(len(x), 0.0005, 0.03)
    save("claw_close", sol + click(0.3, 4000, 0.004))
    save("claw_open", clunk(0.25, 260, 0.02) * 0.7 + click(0.25, 3000, 0.003))

    # 인형 떨어지는 소리(푹신) / 배출구 덜컹
    x = t(0.4)
    thud = lp_fast(rng.standard_normal(len(x)), 300) * env(len(x), 0.002, 0.05) * 4
    thud += 0.5 * np.sin(2 * np.pi * 70 * x) * env(len(x), 0.002, 0.06)
    save("plush_thud", thud)
    flap = clunk(0.35, 90, 0.08) + lp_fast(rng.standard_normal(len(t(0.35))), 1200) * env(len(t(0.35)), 0.001, 0.03)
    save("chute_thud", flap)

    # 타이머 삐 / 시간 끝
    x = t(0.12)
    save("beep", np.sign(np.sin(2 * np.pi * 1000 * x)) * 0.4 * env(len(x), 0.002, 0.08))
    x = t(0.5)
    save("timeup", np.sign(np.sin(2 * np.pi * 620 * x)) * 0.4 * env(len(x), 0.002, 0.3))

    # 게임 시작 징글
    notes = [784, 988, 1175, 1568]
    out = np.zeros(int(0.7 * SR))
    for i, f in enumerate(notes):
        x = t(0.18)
        s = (np.sign(np.sin(2 * np.pi * f * x)) * 0.3 + 0.4 * np.sin(2 * np.pi * f * x)) * env(len(x), 0.003, 0.09)
        k = int(i * 0.1 * SR)
        out[k:k + len(s)] += s
    save("start", out)

    # 당첨 팡파레
    seq = [(523, 0.0), (659, 0.1), (784, 0.2), (1047, 0.3), (784, 0.45), (1047, 0.55), (1319, 0.7)]
    out = np.zeros(int(2.2 * SR))
    for f, st in seq:
        dur = 0.5 if st >= 0.7 else 0.16
        x = t(dur)
        s = (np.sign(np.sin(2 * np.pi * f * x)) * 0.25 + 0.4 * np.sin(2 * np.pi * f * x) + 0.2 * np.sin(2 * np.pi * f * 2 * x))
        s *= env(len(x), 0.004, dur * 0.6)
        k = int(st * SR)
        out[k:k + len(s)] += s
    # 반짝이
    x = t(1.2)
    sp = np.zeros(len(x))
    for i in range(14):
        f = 2000 + 300 * (i % 5)
        k = int(rng.uniform(0, 1.0) * SR)
        y = np.sin(2 * np.pi * f * t(0.12)) * env(len(t(0.12)), 0.001, 0.05)
        sp[k:k + len(y)] += y[:len(sp) - k] * 0.3
    out[int(0.75 * SR):int(0.75 * SR) + len(sp)] += sp
    save("win", out)

    # 아쉬움(놓쳤을 때)
    out = np.zeros(int(0.9 * SR))
    for i, f in enumerate((440, 415, 392)):
        x = t(0.28)
        s = np.sign(np.sin(2 * np.pi * f * x)) * 0.3 * env(len(x), 0.004, 0.2)
        k = int(i * 0.22 * SR)
        out[k:k + len(s)] += s
    save("miss", out)

    # 캡슐 뽑기: 손잡이 래칫 / 캡슐 굴러나옴
    out = np.zeros(int(1.3 * SR))
    for i in range(10):
        c = click(0.05, 2200 + 200 * (i % 2), 0.006) + clunk(0.05, 500, 0.008) * 0.4
        k = int(i * 0.12 * SR)
        out[k:k + len(c)] += c
    save("gacha_crank", out)
    out = np.zeros(int(1.0 * SR))
    for i, st in enumerate((0.0, 0.18, 0.31, 0.4, 0.47, 0.52)):
        c = clunk(0.12, 600 + 80 * i, 0.012) * (1 - i * 0.13) + click(0.12, 3500, 0.003) * 0.5
        k = int(st * SR)
        out[k:k + len(c)] += c
    save("capsule_drop", out)

    # 지폐교환기: 지폐 넘기는 소리
    out = np.zeros(int(1.4 * SR))
    for i in range(10):
        c = bp_fast(rng.standard_normal(int(0.05 * SR)), 1500, 7000) * env(int(0.05 * SR), 0.002, 0.012)
        k = int((0.25 + i * 0.08) * SR)
        out[k:k + len(c)] += c
    m = motor(1.4, f=160, whine=1700, rough=0.3) * 0.25
    save("changer", out + m)

    # 발걸음(가게 바닥)
    for i in range(3):
        x = t(0.18)
        s = lp_fast(rng.standard_normal(len(x)), 900 + 200 * i) * env(len(x), 0.002, 0.03) * 3
        s += 0.3 * np.sin(2 * np.pi * (90 + 10 * i) * x) * env(len(x), 0.002, 0.04)
        save(f"step{i}", s)

    # 버튼 UI 클릭
    save("ui", click(0.06, 2400, 0.008))


# ----------------------------------------------------------------- 배경음악
def bgm():
    sr = 22050
    bpm = 126
    beat = 60 / bpm
    bars = 16
    total = int(bars * 4 * beat * sr)
    out = np.zeros(total)

    def note_f(n):
        return 440 * 2 ** ((n - 69) / 12)

    def add(sig, start_beat):
        k = int(start_beat * beat * sr)
        if k >= total:
            return
        e = min(total, k + len(sig))
        out[k:e] += sig[:e - k]

    def tone(n, dur_beats, wave="sq", vol=0.2, duty=0.5):
        d = dur_beats * beat
        x = np.arange(int(d * sr)) / sr
        f = note_f(n)
        ph = (x * f) % 1.0
        if wave == "sq":
            s = np.where(ph < duty, 1.0, -1.0)
        elif wave == "tri":
            s = 4 * np.abs(ph - 0.5) - 1
        else:
            s = np.sin(2 * np.pi * f * x)
        a = np.minimum(1, x / 0.008)
        r = np.clip((d - x) / 0.04, 0, 1)
        dec = 0.65 + 0.35 * np.exp(-x / 0.25)
        return s * a * r * dec * vol

    # 코드 진행 (C - G - Am - F) x4, 마지막은 F - G
    chords = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]] * 3 + [[60, 64, 67], [55, 59, 62], [53, 57, 60], [55, 59, 62]]
    # 멜로디(오리지널): 마디당 8분음표 8개, -1 은 쉼표
    mel = [
        [72, -1, 76, 79, 77, 76, 74, 72], [71, -1, 74, 79, 77, 74, 71, -1],
        [72, 76, 81, 79, 76, -1, 72, 74], [77, 76, 74, 72, 74, -1, -1, -1],
        [72, -1, 76, 79, 81, 79, 76, 79], [74, -1, 79, 83, 81, 79, 74, -1],
        [76, 79, 84, 83, 81, 79, 76, -1], [77, 81, 79, 77, 76, 74, 72, -1],
        [84, -1, 83, 81, 79, -1, 76, 79], [79, 77, 76, 74, 71, -1, 74, -1],
        [76, 77, 79, 81, 84, 81, 79, 76], [77, -1, 76, -1, 74, -1, 72, -1],
        [72, 76, 79, 84, 79, 76, 72, 76], [71, 74, 79, 83, 79, 74, 71, 74],
        [69, 72, 77, 81, 77, 72, 69, 72], [71, 74, 77, 79, 83, -1, -1, -1],
    ]
    for b in range(bars):
        ch = chords[b]
        root = ch[0] - 24
        # 베이스(삼각파) 8분 리듬
        for i in range(8):
            n = root if i % 2 == 0 else root + 12
            add(tone(n, 0.45, "tri", 0.32), b * 4 + i * 0.5)
        # 아르페지오(가는 사각파)
        for i in range(16):
            n = ch[i % 3] + 12
            add(tone(n, 0.22, "sq", 0.05, duty=0.25), b * 4 + i * 0.25)
        # 멜로디
        for i, n in enumerate(mel[b]):
            if n > 0:
                length = 0.5
                if i + 1 < 8 and mel[b][i + 1] == -1:
                    length = 0.95
                add(tone(n, length * 0.95, "sq", 0.11, duty=0.5), b * 4 + i * 0.5)
        # 드럼: 킥/스네어/하이햇(노이즈)
        for i in range(4):
            kx = np.arange(int(0.15 * sr)) / sr
            kick = np.sin(2 * np.pi * (50 + 120 * np.exp(-kx / 0.03)) * kx) * np.exp(-kx / 0.08) * 0.5
            if i in (0, 2):
                add(kick, b * 4 + i)
            else:
                nz = rng.standard_normal(int(0.12 * sr)) * np.exp(-np.arange(int(0.12 * sr)) / sr / 0.04) * 0.18
                add(nz, b * 4 + i)
            for h in (0, 0.5):
                hh = rng.standard_normal(int(0.04 * sr))
                hh = hh - np.convolve(hh, np.ones(4) / 4, mode="same")
                add(hh * np.exp(-np.arange(len(hh)) / sr / 0.01) * 0.07, b * 4 + i + h)
    save("bgm_arcade", out, sr=sr, peak=0.7)


if __name__ == "__main__":
    sfx()
    bgm()
