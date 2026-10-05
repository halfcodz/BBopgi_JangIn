"""추가 텍스처: 일본식 UFO 기계 간판/조작판, 새 상품 인쇄(키캡·전자기기 경품 상자 등)."""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from gen_textures import FONT_BHS, FONT_DH, FONT_JUA, font, outlined_text, save, star, heart

rng = np.random.default_rng(7)


def header_ufo():
    W, H = 1024, 256
    img = Image.new("RGB", (W, H), (246, 248, 252))
    d = ImageDraw.Draw(img)
    # 은은한 하늘색 그라데이션 띠 + 반짝이
    for y in range(H):
        t = y / H
        c = (int(236 + 14 * t), int(242 + 8 * t), 255)
        d.line([(0, y), (W, y)], fill=c)
    for k in range(40):
        star(d, rng.uniform(0, W), rng.uniform(10, H - 10), rng.uniform(5, 14),
             [(120, 190, 255), (255, 150, 200), (255, 210, 90), (140, 230, 170)][k % 4], rot=rng.uniform(0, 1))
    d.rectangle([0, H - 26, W, H], fill=(60, 140, 255))
    d.rectangle([0, 0, W, 18], fill=(60, 140, 255))
    save(img, "machine/header_ufo.png")


def panel_ufo():
    W, H = 512, 256
    img = Image.new("RGB", (W, H), (244, 246, 250))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 10, W - 10, H - 10], 26, outline=(80, 150, 255), width=8)
    d.rounded_rectangle([24, 24, W - 24, H - 24], 20, outline=(200, 215, 235), width=3)
    save(img, "machine/panel_ufo.png")


def _main_basic():
    which = sys.argv[1:] or ["header_ufo", "panel_ufo"]
    for w in which:
        globals()[w]()


# ------------------------------------------------------------------ 경품 상자 아틀라스(JP_RECTS 배치)
RECTS = {"front": (0.0, 0.0, 0.6, 0.4), "back": (0.0, 0.4, 0.6, 0.8), "top": (0.0, 0.8, 0.6, 1.0),
         "right": (0.6, 0.0, 0.8, 0.4), "left": (0.8, 0.0, 1.0, 0.4)}


def atlas(name, faces, bg=(255, 255, 255)):
    """faces: 면 이름 → (그리기 함수(draw, w, h), 실제 가로세로 비율). 면마다 비율에 맞게 그린 뒤 아틀라스 칸에 맞춰 넣는다."""
    N = 1024
    img = Image.new("RGB", (N, N), bg)
    for k, (fn, aspect) in faces.items():
        u0, v0, u1, v1 = RECTS[k]
        h = 512
        w = int(h * aspect)
        face = Image.new("RGB", (w, h), bg)
        fn(ImageDraw.Draw(face), w, h)
        x0, y0, x1, y1 = int(u0 * N), int(v0 * N), int(u1 * N), int(v1 * N)
        img.paste(face.resize((x1 - x0, y1 - y0), Image.LANCZOS), (x0, y0))
    save(img, f"prizes/{name}.png")


def fit(d, xy, text, path, size, w_max, fill, outline, width):
    while size > 8:
        f = font(path, size)
        if d.textlength(text, font=f) <= w_max:
            break
        size -= 2
    outlined_text(d, xy, text, font(path, size), fill, outline, width)


def _brand(d, w, h, col, title, sub, art, accent=(255, 255, 255)):
    d.rectangle([0, 0, w, h], fill=col)
    d.rectangle([0, 0, w, int(h * 0.13)], fill=tuple(max(0, c - 40) for c in col))
    fit(d, (w * 0.5, h * 0.065), "POPPI ELECTRONICS", FONT_BHS, int(h * 0.07), w * 0.9, (255, 255, 255), (0, 0, 0), 0)
    art(d, w * 0.5, h * 0.46, min(w, h) * 0.34)
    fit(d, (w * 0.5, h * 0.8), title, FONT_BHS, int(h * 0.1), w * 0.92, accent, (30, 30, 50), 4)
    fit(d, (w * 0.5, h * 0.91), sub, FONT_JUA, int(h * 0.055), w * 0.92, (255, 255, 255), (30, 30, 50), 2)


def _side(col, text):
    def f(d, w, h):
        d.rectangle([0, 0, w, h], fill=col)
        fit(d, (w * 0.5, h * 0.25), "POPPI", FONT_BHS, int(w * 0.22), w * 0.9, (255, 255, 255), (0, 0, 0), 0)
        star(d, w * 0.5, h * 0.5, w * 0.2, (255, 230, 90))
        fit(d, (w * 0.5, h * 0.78), text, FONT_JUA, int(w * 0.2), w * 0.9, (255, 255, 255), (30, 30, 50), 2)
    return f


def _back(col, lines):
    def f(d, w, h):
        d.rectangle([0, 0, w, h], fill=tuple(min(255, c + 30) for c in col))
        for i, ln in enumerate(lines):
            fit(d, (w * 0.5, h * (0.2 + i * 0.16)), ln, FONT_JUA, int(h * 0.075), w * 0.9, (40, 40, 60), (255, 255, 255), 0)
    return f


def _top(col, text):
    def f(d, w, h):
        d.rectangle([0, 0, w, h], fill=col)
        fit(d, (w * 0.5, h * 0.5), text, FONT_BHS, int(h * 0.35), w * 0.9, (255, 255, 255), (30, 30, 50), 3)
    return f


def art_earbuds(d, cx, cy, s):
    d.rounded_rectangle([cx - s * 0.8, cy - s * 0.45, cx + s * 0.8, cy + s * 0.65], s * 0.45, fill=(250, 250, 252), outline=(200, 200, 210), width=4)
    d.line([cx - s * 0.75, cy - s * 0.05, cx + s * 0.75, cy - s * 0.05], fill=(205, 205, 215), width=4)
    d.ellipse([cx - s * 0.08, cy + s * 0.15, cx + s * 0.08, cy + s * 0.3], fill=(120, 230, 160))
    for sx in (-1, 1):
        x = cx + sx * s * 0.42
        d.ellipse([x - s * 0.2, cy - s * 0.95, x + s * 0.2, cy - s * 0.55], fill=(255, 255, 255), outline=(190, 190, 200), width=3)
        d.rounded_rectangle([x - s * 0.06, cy - s * 0.65, x + s * 0.06, cy - s * 0.3], s * 0.05, fill=(255, 255, 255), outline=(190, 190, 200), width=3)


def art_powerbank(d, cx, cy, s):
    d.rounded_rectangle([cx - s * 0.5, cy - s * 0.95, cx + s * 0.5, cy + s * 0.95], s * 0.15, fill=(60, 64, 80), outline=(30, 30, 40), width=4)
    for i in range(4):
        d.ellipse([cx - s * 0.32 + i * s * 0.2, cy + s * 0.6, cx - s * 0.22 + i * s * 0.2, cy + s * 0.7], fill=(90, 220, 255))
    outlined_text(d, (cx, cy - s * 0.2), "10000", font(FONT_BHS, int(s * 0.32)), (255, 255, 255), (0, 0, 0), 0)
    outlined_text(d, (cx, cy + s * 0.15), "mAh", font(FONT_JUA, int(s * 0.22)), (180, 220, 255), (0, 0, 0), 0)


def art_fan(d, cx, cy, s):
    d.rounded_rectangle([cx - s * 0.12, cy + s * 0.2, cx + s * 0.12, cy + s * 1.05], s * 0.1, fill=(255, 190, 210))
    d.ellipse([cx - s * 0.6, cy - s * 0.95, cx + s * 0.6, cy + s * 0.25], fill=(255, 255, 255), outline=(255, 150, 185), width=8)
    for k in range(5):
        a = k * 2 * math.pi / 5
        x, y = cx + math.cos(a) * s * 0.3, cy - s * 0.35 + math.sin(a) * s * 0.3
        d.ellipse([x - s * 0.2, y - s * 0.12, x + s * 0.2, y + s * 0.12], fill=(255, 175, 200))
    d.ellipse([cx - s * 0.1, cy - s * 0.45, cx + s * 0.1, cy - s * 0.25], fill=(255, 120, 160))


def art_speaker(d, cx, cy, s):
    d.rounded_rectangle([cx - s * 0.75, cy - s * 0.75, cx + s * 0.75, cy + s * 0.8], s * 0.35, fill=(70, 90, 140))
    for r in (0.55, 0.38, 0.2):
        d.ellipse([cx - s * r, cy - s * r, cx + s * r, cy + s * r], outline=(200, 220, 255), width=6)
    for i in range(-5, 6):
        for j in range(-5, 6):
            if i * i + j * j < 22:
                d.ellipse([cx + i * s * 0.1 - 3, cy + j * s * 0.1 - 3, cx + i * s * 0.1 + 3, cy + j * s * 0.1 + 3], fill=(40, 50, 80))


def art_lamp(d, cx, cy, s):
    for r, a in ((1.0, 40), (0.8, 70), (0.62, 120)):
        d.ellipse([cx - s * r, cy - s * r * 0.95, cx + s * r, cy + s * r * 0.95], fill=(255, 235, 160 + a // 3))
    d.ellipse([cx - s * 0.55, cy - s * 0.55, cx + s * 0.55, cy + s * 0.55], fill=(255, 245, 200))
    for (x, y, r) in ((-0.2, -0.15, 0.1), (0.15, 0.1, 0.07), (0.05, -0.3, 0.05), (-0.1, 0.25, 0.06)):
        d.ellipse([cx + s * (x - r), cy + s * (y - r), cx + s * (x + r), cy + s * (y + r)], fill=(235, 220, 170))
    d.rectangle([cx - s * 0.35, cy + s * 0.7, cx + s * 0.35, cy + s * 0.85], fill=(160, 120, 90))


GADGETS = {
    "gift_earbuds": ((0.10, 0.11, 0.05), (90, 180, 240), "무선 이어폰", "블루투스 5.3, 충전 케이스", art_earbuds),
    "gift_powerbank": ((0.085, 0.14, 0.035), (70, 80, 110), "보조배터리", "10000mAh 고속 충전", art_powerbank),
    "gift_fan": ((0.09, 0.17, 0.06), (255, 140, 180), "휴대용 미니 선풍기", "3단 바람, USB 충전", art_fan),
    "gift_speaker": ((0.11, 0.11, 0.10), (60, 80, 150), "블루투스 스피커", "방수, 12시간 재생", art_speaker),
    "gift_lamp": ((0.10, 0.13, 0.10), (240, 170, 70), "LED 무드등", "달 모양, 터치 3단", art_lamp),
}


def gadgets():
    for gid, (size, col, title, sub, art) in GADGETS.items():
        sx, sy, sz = size
        atlas(gid, {
            "front": (lambda d, w, h, col=col, title=title, sub=sub, art=art: _brand(d, w, h, col, title, sub, art), sx / sy),
            "back": (_back(col, ["구성품: 본체, 케이블", "설명서 1부", "본 상품은 경품입니다", "만 8세 이상"]), sx / sy),
            "top": (_top(col, title), sx / sz),
            "right": (_side(col, title), sz / sy),
            "left": (_side(col, title), sz / sy),
        })


# ------------------------------------------------------------------ 새 일본식 피규어(오리지널 캐릭터)
def _cat_girl(d, cx, cy, s):
    for sx in (-1, 1):
        d.polygon([(cx + sx * 30 * s, cy - 135 * s), (cx + sx * 70 * s, cy - 190 * s), (cx + sx * 75 * s, cy - 110 * s)], fill=(120, 90, 200))
    d.ellipse([cx - 70 * s, cy - 150 * s, cx + 70 * s, cy - 10 * s], fill=(130, 100, 210))
    d.ellipse([cx - 55 * s, cy - 130 * s, cx + 55 * s, cy - 25 * s], fill=(255, 230, 215))
    d.pieslice([cx - 70 * s, cy - 160 * s, cx + 70 * s, cy - 50 * s], 180, 360, fill=(110, 80, 190))
    for sx in (-1, 1):
        d.ellipse([cx + sx * 22 * s - 11 * s, cy - 85 * s, cx + sx * 22 * s + 11 * s, cy - 60 * s], fill=(240, 180, 40))
        d.ellipse([cx + sx * 22 * s - 3 * s, cy - 82 * s, cx + sx * 22 * s + 4 * s, cy - 74 * s], fill=(255, 255, 255))
    d.arc([cx - 12 * s, cy - 58 * s, cx + 12 * s, cy - 45 * s], 20, 160, fill=(200, 80, 100), width=int(3 * s))
    d.polygon([(cx - 45 * s, cy - 15 * s), (cx + 45 * s, cy - 15 * s), (cx + 75 * s, cy + 115 * s), (cx - 75 * s, cy + 115 * s)], fill=(60, 50, 110))
    d.polygon([(cx - 75 * s, cy + 70 * s), (cx + 75 * s, cy + 70 * s), (cx + 90 * s, cy + 125 * s), (cx - 90 * s, cy + 125 * s)], fill=(250, 220, 90))
    d.line([(cx + 70 * s, cy + 90 * s), (cx + 130 * s, cy + 20 * s), (cx + 120 * s, cy - 20 * s)], fill=(120, 90, 200), width=int(10 * s))
    star(d, cx - 110 * s, cy - 100 * s, 26 * s, (255, 230, 90))


def _dragon(d, cx, cy, s):
    d.ellipse([cx - 80 * s, cy - 20 * s, cx + 80 * s, cy + 120 * s], fill=(110, 200, 140))
    d.ellipse([cx - 50 * s, cy + 10 * s, cx + 50 * s, cy + 110 * s], fill=(250, 240, 190))
    d.ellipse([cx - 75 * s, cy - 160 * s, cx + 75 * s, cy - 20 * s], fill=(110, 200, 140))
    for sx in (-1, 1):
        d.polygon([(cx + sx * 40 * s, cy - 150 * s), (cx + sx * 55 * s, cy - 200 * s), (cx + sx * 65 * s, cy - 140 * s)], fill=(255, 230, 120))
        d.polygon([(cx + sx * 75 * s, cy - 10 * s), (cx + sx * 150 * s, cy - 80 * s), (cx + sx * 130 * s, cy + 30 * s)], fill=(90, 170, 120))
        d.ellipse([cx + sx * 28 * s - 13 * s, cy - 110 * s, cx + sx * 28 * s + 13 * s, cy - 80 * s], fill=(30, 30, 40))
        d.ellipse([cx + sx * 28 * s - 4 * s, cy - 106 * s, cx + sx * 28 * s + 3 * s, cy - 98 * s], fill=(255, 255, 255))
    d.ellipse([cx - 30 * s, cy - 65 * s, cx + 30 * s, cy - 35 * s], fill=(150, 225, 170))
    d.arc([cx - 15 * s, cy - 60 * s, cx + 15 * s, cy - 40 * s], 20, 160, fill=(40, 90, 60), width=int(3 * s))


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "goods":
    gadgets()
    from gen_textures import jp_figure
    jp_figure("jp_figure_c", (215, 200, 255), (110, 80, 200), "냥냥 마법사", "밤하늘 Ver.", _cat_girl)
    jp_figure("jp_figure_d", (200, 245, 210), (60, 160, 100), "아기용 루루", "날개 Ver.", _dragon)


if __name__ == "__main__" and not (len(sys.argv) > 1 and sys.argv[1] in ("goods", "interior", "header")):
    _main_basic()


# ------------------------------------------------------------------ 네온 뽑기방 인테리어
def floor_bw():
    """광택 흑백 체크 바닥(타일 2×2 = 1.2m)."""
    N = 1024
    img = Image.new("RGB", (N, N))
    d = ImageDraw.Draw(img)
    h = N // 2
    for i in range(2):
        for j in range(2):
            col = (236, 236, 240) if (i + j) % 2 == 0 else (24, 22, 28)
            d.rectangle([i * h, j * h, i * h + h, j * h + h], fill=col)
    # 은은한 대리석 결
    arr = np.asarray(img).astype(np.float32)
    yy, xx = np.mgrid[0:N, 0:N]
    vein = np.sin((xx * 0.012 + yy * 0.007) + 3.0 * np.sin(yy * 0.004 + xx * 0.002)) * 0.5 + 0.5
    vein = np.clip((vein - 0.93) / 0.07, 0, 1)
    arr += vein[..., None] * np.where(arr > 128, -18, 22)
    arr += rng.normal(0, 2.0, arr.shape)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for k in range(3):
        d.line([(k * h, 0), (k * h, N)], fill=(120, 120, 130), width=3)
        d.line([(0, k * h), (N, k * h)], fill=(120, 120, 130), width=3)
    save(img, "shop/floor_bw.png")


def wall_neon():
    """연보라 벽 패널 + 얇은 세로 줄눈."""
    W, H = 1024, 512
    img = Image.new("RGB", (W, H), (226, 206, 236))
    d = ImageDraw.Draw(img)
    for x in range(0, W, 128):
        d.rectangle([x, 0, x + 3, H], fill=(205, 182, 220))
    arr = np.asarray(img).astype(np.float32)
    yy = np.linspace(0, 1, H)[:, None, None]
    arr *= (0.92 + 0.08 * yy)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    save(img, "shop/wall_neon.png")


def ceiling_dark():
    N = 512
    img = Image.new("RGB", (N, N), (34, 28, 44))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, N, 4], fill=(48, 40, 60))
    d.rectangle([0, 0, 4, N], fill=(48, 40, 60))
    save(img, "shop/ceiling_dark.png")


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "interior":
    floor_bw()
    wall_neon()
    ceiling_dark()


def header_neutral():
    """테마색으로 물들이는 흰 간판: 가장자리 그라데이션 + 발바닥·별·하트 무늬."""
    W, H = 1024, 256
    img = Image.new("RGB", (W, H), (255, 255, 255))
    arr = np.asarray(img).astype(np.float32)
    yy = np.linspace(-1, 1, H)[:, None, None]
    arr *= (1.0 - 0.22 * yy ** 2)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    def paw(cx, cy, s, col):
        d.ellipse([cx - s, cy - s * 0.6, cx + s, cy + s * 0.9], fill=col)
        for k, (dx, dy) in enumerate(((-1.1, -1.2), (-0.4, -1.6), (0.4, -1.6), (1.1, -1.2))):
            d.ellipse([cx + dx * s - s * 0.35, cy + dy * s - s * 0.4, cx + dx * s + s * 0.35, cy + dy * s + s * 0.4], fill=col)
    for i in range(14):
        x = 40 + i * 72
        col = (235, 225, 240)
        if i % 3 == 0:
            paw(x, 200 if i % 2 else 60, 12, col)
        elif i % 3 == 1:
            star(d, x, 205 if i % 2 else 52, 14, col)
        else:
            heart(d, x, 200 if i % 2 else 58, 26, col)
    save(img, "machine/header_neutral.png")


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "header":
    header_neutral()
