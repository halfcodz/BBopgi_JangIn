"""원단·실 텍스처 생성 (모두 이음새 없이 반복되는 타일)."""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "fabric")
rng = np.random.default_rng(7)


def periodic_noise(n, lo_freq, hi_freq, aniso=1.0, angle=0.0, seed=None):
    r = np.random.default_rng(seed)
    white = r.standard_normal((n, n))
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    ca, sa = np.cos(angle), np.sin(angle)
    u = fx * ca + fy * sa
    v = -fx * sa + fy * ca
    f = np.sqrt(u * u + (v * aniso) ** 2)
    band = np.exp(-((f - (lo_freq + hi_freq) / 2) / ((hi_freq - lo_freq) / 2 + 1e-6)) ** 2)
    out = np.real(np.fft.ifft2(F * band))
    out -= out.mean()
    out /= out.std() + 1e-9
    return out


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -dx * strength
    ny = dy * strength  # OpenGL 방식 (Godot 기본)
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(arr, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(OUT, name))
    print("saved", name)


def minky():
    n = 512
    # 짧은 털: 아주 고운 섬유 + 털 뭉침(클럼프) + 살짝 결 방향
    fine = periodic_noise(n, 90, 200, aniso=2.5, angle=0.3, seed=1)
    clump = periodic_noise(n, 12, 30, aniso=1.4, angle=0.3, seed=2)
    patch = periodic_noise(n, 2, 6, seed=3)
    h = 0.55 * fine + 0.35 * clump + 0.1 * patch
    alb = 0.88 + 0.06 * np.tanh(clump * 0.8) + 0.035 * np.tanh(fine) + 0.02 * patch
    save((np.clip(alb, 0, 1) * 255).astype(np.uint8), "minky_albedo.png")
    save(normal_from_height(h, 1.6), "minky_normal.png")


def velboa():
    """긴 털(벨보아) – 토끼·고양이용, 결이 더 굵고 방향성이 강함."""
    n = 512
    fine = periodic_noise(n, 50, 120, aniso=4.0, angle=1.2, seed=11)
    clump = periodic_noise(n, 8, 20, aniso=2.5, angle=1.2, seed=12)
    h = 0.5 * fine + 0.5 * clump
    alb = 0.86 + 0.08 * np.tanh(clump) + 0.03 * np.tanh(fine)
    save((np.clip(alb, 0, 1) * 255).astype(np.uint8), "velboa_albedo.png")
    save(normal_from_height(h, 2.4), "velboa_normal.png")


def satin_thread():
    """자수 실(새틴 스티치) – 가는 실이 나란히 놓인 결."""
    n = 256
    y = np.arange(n)[:, None]
    x = np.arange(n)[None, :]
    strands = np.sin((y + 3 * np.sin(x / n * 2 * np.pi * 2)) / n * 2 * np.pi * 24) * 0.5 + 0.5
    strands = strands ** 0.6
    twist = periodic_noise(n, 30, 60, aniso=6, angle=0.0, seed=21) * 0.15
    h = strands + twist
    alb = 0.75 + 0.25 * strands
    save((np.clip(alb, 0, 1) * 255).astype(np.uint8), "thread_albedo.png")
    save(normal_from_height(h, 3.0), "thread_normal.png")


def felt():
    n = 256
    h = periodic_noise(n, 20, 80, seed=31) * 0.6 + periodic_noise(n, 80, 128, seed=32) * 0.4
    save(normal_from_height(h, 1.2), "felt_normal.png")


if __name__ == "__main__":
    minky()
    velboa()
    satin_thread()
    felt()
