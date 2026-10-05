"""음료 자판기 텍스처: 캔·페트병 라벨 아틀라스(4x4), 간판, 가운데 광고판, 옆면 랩핑.
브랜드는 모두 가상의 이름이다.
실행: python gen_vending.py
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from gen_textures import FONT_BHS, FONT_DH, FONT_JUA, font, save

rng = np.random.default_rng(11)

LW, LH = 512, 256  # 라벨 한 칸(가로 = 캔 둘레 한 바퀴)


def grad(w, h, c1, c2, vertical=True):
    a = np.linspace(0, 1, h if vertical else w)
    c1 = np.array(c1, float)
    c2 = np.array(c2, float)
    line = (c1[None, :] * (1 - a[:, None]) + c2[None, :] * a[:, None]).astype(np.uint8)
    if vertical:
        arr = np.repeat(line[:, None, :], w, axis=1)
    else:
        arr = np.repeat(line[None, :, :], h, axis=0)
    return Image.fromarray(arr, "RGB")


def fit_text(d, xy, text, path, size, w_max, fill, stroke=None, sw=0, anchor="mm"):
    while size > 8:
        f = font(path, size)
        if d.textlength(text, font=f) <= w_max:
            break
        size -= 2
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)


def bubbles(d, w, h, n, col, rmin=3, rmax=10):
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(rmin, rmax)
        d.ellipse([x - r, y - r, x + r, y + r], outline=col, width=2)


def wave(d, w, y, amp, col, thick, phase=0.0, period=1.0):
    pts = []
    for x in range(0, w + 8, 8):
        pts.append((x, y + amp * math.sin(x / w * TAU * period + phase)))
    pts2 = [(x, yy + thick) for x, yy in reversed(pts)]
    d.polygon(pts + pts2, fill=col)


TAU = math.tau


def fruit(d, cx, cy, r, col, seg=(255, 255, 255)):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    d.ellipse([cx - r * 0.82, cy - r * 0.82, cx + r * 0.82, cy + r * 0.82], fill=tuple(min(255, c + 40) for c in col))
    for k in range(8):
        a = k / 8 * TAU
        d.line([cx, cy, cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8], fill=seg, width=3)


def leaf(d, cx, cy, s, col, ang=0.0):
    pts = []
    for k in range(24):
        t = k / 23 * math.pi
        x = math.cos(t) * s
        y = math.sin(t) * s * 0.42
        pts.append((x, y))
    pts += [(x, -y) for x, y in reversed(pts)]
    ca, sa = math.cos(ang), math.sin(ang)
    d.polygon([(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts], fill=col)


def bean(d, cx, cy, s, col):
    d.ellipse([cx - s, cy - s * 0.7, cx + s, cy + s * 0.7], fill=col)
    d.arc([cx - s * 0.5, cy - s * 0.7, cx + s * 0.5, cy + s * 0.7], 270, 90, fill=(40, 20, 10), width=3)


# ---------------------------------------------------------------- 라벨 하나하나
def lab_cola(img, d):
    d.rectangle([0, 0, LW, LH], fill=(200, 16, 32))
    wave(d, LW, 168, 14, (255, 255, 255), 14, 0.0, 2)
    wave(d, LW, 190, 10, (120, 0, 12), 30, 1.0, 2)
    fit_text(d, (256, 100), "COLAX", FONT_BHS, 92, 300, (255, 255, 255), (120, 0, 12), 3)
    fit_text(d, (256, 150), "콜락스 오리지널", FONT_JUA, 26, 260, (255, 230, 230))
    fit_text(d, (60, 120), "COLAX", FONT_BHS, 40, 110, (255, 220, 220))
    fit_text(d, (452, 120), "355ml", FONT_DH, 34, 110, (255, 220, 220))


def lab_cider(img, d):
    img.paste(grad(LW, LH, (240, 252, 245), (170, 230, 190)))
    d = ImageDraw.Draw(img)
    bubbles(d, LW, LH, 40, (90, 190, 120), 3, 9)
    d.rectangle([0, 52, LW, 62], fill=(30, 150, 70))
    d.rectangle([0, 200, LW, 210], fill=(30, 150, 70))
    fit_text(d, (256, 118), "별빛사이다", FONT_BHS, 70, 290, (20, 120, 60), (255, 255, 255), 4)
    fit_text(d, (256, 172), "STARLIGHT CIDER", FONT_DH, 28, 260, (30, 140, 70))
    d.polygon([(256 + 26 * math.cos(a) * (1 if k % 2 == 0 else 0.45), 30 + 26 * math.sin(a) * (1 if k % 2 == 0 else 0.45) * 0.8)
               for k, a in enumerate([i / 10 * TAU - math.pi / 2 for i in range(10)])], fill=(255, 200, 40))
    return d


def lab_coffee(img, d):
    img.paste(grad(LW, LH, (70, 38, 22), (35, 18, 10)))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 34, LW, 40], fill=(214, 170, 90))
    d.rectangle([0, 216, LW, 222], fill=(214, 170, 90))
    for k in range(6):
        bean(d, 80 + k * 70 + (0 if k % 2 else 20), 196 if k % 2 else 60, 12, (150, 90, 45))
    fit_text(d, (256, 112), "아침커피", FONT_BHS, 72, 290, (245, 225, 190), (30, 14, 6), 3)
    fit_text(d, (256, 162), "MORNING BLACK", FONT_DH, 30, 260, (214, 170, 90))
    return d


def lab_energy(img, d):
    d.rectangle([0, 0, LW, LH], fill=(18, 18, 22))
    for k in range(3):
        x = 150 + k * 100
        d.polygon([(x, 20), (x + 30, 20), (x + 8, 120), (x + 40, 120), (x - 20, 240), (x - 4, 140), (x - 34, 140)], fill=(150, 240, 30))
    d = ImageDraw.Draw(img)
    fit_text(d, (256, 132), "VOLT", FONT_BHS, 110, 300, (255, 255, 255), (20, 20, 20), 5)
    fit_text(d, (256, 205), "에너지 드링크", FONT_JUA, 26, 220, (150, 240, 30))
    return d


def lab_peach(img, d):
    img.paste(grad(LW, LH, (255, 214, 190), (250, 150, 130)))
    d = ImageDraw.Draw(img)
    for cx in (110, 400):
        d.ellipse([cx - 40, 150, cx + 40, 230], fill=(245, 120, 110))
        d.ellipse([cx - 28, 162, cx + 6, 196], fill=(255, 190, 170))
        leaf(d, cx + 22, 148, 24, (90, 160, 70), -0.6)
    fit_text(d, (256, 82), "복숭아", FONT_BHS, 76, 280, (200, 50, 70), (255, 255, 255), 4)
    fit_text(d, (256, 140), "아이스티", FONT_JUA, 46, 260, (120, 40, 50))
    fit_text(d, (256, 196), "PEACH ICED TEA", FONT_DH, 24, 200, (255, 255, 255))
    return d


def lab_orange(img, d):
    img.paste(grad(LW, LH, (255, 170, 30), (240, 110, 10)))
    d = ImageDraw.Draw(img)
    fruit(d, 256, 196, 48, (250, 130, 0), (255, 230, 160))
    leaf(d, 300, 146, 26, (60, 150, 50), -0.3)
    fit_text(d, (256, 72), "오렌지 100", FONT_BHS, 66, 300, (255, 255, 255), (190, 70, 0), 4)
    fit_text(d, (256, 122), "ORANGE JUICE", FONT_DH, 28, 260, (120, 40, 0))
    return d


def lab_sikhye(img, d):
    d.rectangle([0, 0, LW, LH], fill=(246, 236, 210))
    for k in range(40):
        x, y = rng.uniform(0, LW), rng.uniform(170, 250)
        d.ellipse([x - 5, y - 3, x + 5, y + 3], fill=(230, 215, 180))
    d.rectangle([0, 0, LW, 40], fill=(140, 40, 30))
    d.rectangle([0, 40, LW, 46], fill=(214, 170, 60))
    d.ellipse([196, 70, 316, 190], fill=(140, 40, 30))
    fit_text(d, (256, 132), "식혜", FONT_BHS, 70, 110, (250, 240, 215))
    fit_text(d, (256, 222), "전통 쌀음료", FONT_JUA, 30, 220, (110, 60, 30))
    fit_text(d, (80, 130), "밥알", FONT_JUA, 40, 100, (140, 40, 30))
    fit_text(d, (432, 130), "듬뿍", FONT_JUA, 40, 100, (140, 40, 30))
    return d


def lab_grape(img, d):
    img.paste(grad(LW, LH, (120, 40, 160), (60, 10, 90)))
    d = ImageDraw.Draw(img)
    bubbles(d, LW, LH, 30, (190, 130, 230), 3, 8)
    for k in range(10):
        row = [0, 1, 1, 2, 2, 2, 3, 3, 3, 3][k]
        idx = [0, 0, 1, 0, 1, 2, 0, 1, 2, 3][k]
        cx = 256 - row * 13 + idx * 26
        cy = 222 - row * 22
        d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(170, 80, 210), outline=(80, 20, 110), width=2)
    fit_text(d, (256, 70), "GRAPE FIZZ", FONT_BHS, 64, 320, (255, 255, 255), (60, 10, 90), 4)
    fit_text(d, (256, 122), "톡쏘는 포도", FONT_JUA, 34, 260, (240, 210, 255))
    return d


def lab_latte(img, d):
    img.paste(grad(LW, LH, (250, 245, 232), (230, 215, 190)))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, LW, 60], fill=(40, 70, 140))
    fit_text(d, (256, 32), "CAFE LATTE", FONT_DH, 36, 300, (255, 255, 255))
    # 컵
    d.polygon([(206, 120), (306, 120), (296, 220), (216, 220)], fill=(255, 255, 255), outline=(40, 70, 140))
    d.ellipse([206, 110, 306, 132], fill=(180, 130, 80))
    d.arc([296, 140, 336, 190], 270, 90, fill=(40, 70, 140), width=6)
    fit_text(d, (110, 150), "라떼", FONT_BHS, 54, 150, (40, 70, 140))
    fit_text(d, (410, 150), "한잔", FONT_BHS, 54, 150, (40, 70, 140))
    fit_text(d, (256, 240), "부드러운 우유 커피", FONT_JUA, 20, 260, (110, 80, 50))
    return d


def lab_lemon(img, d):
    img.paste(grad(LW, LH, (255, 250, 200), (255, 228, 80)))
    d = ImageDraw.Draw(img)
    bubbles(d, LW, LH, 35, (230, 190, 40), 3, 8)
    d.ellipse([200, 140, 312, 220], fill=(250, 210, 20), outline=(200, 160, 0), width=3)
    leaf(d, 300, 140, 22, (80, 160, 60), -0.5)
    fit_text(d, (256, 62), "LEMON SODA", FONT_BHS, 60, 320, (40, 120, 60), (255, 255, 255), 4)
    fit_text(d, (256, 112), "레몬 탄산수  무설탕", FONT_JUA, 28, 280, (80, 110, 40))
    return d


def lab_mango(img, d):
    img.paste(grad(LW, LH, (255, 230, 120), (255, 150, 40)))
    d = ImageDraw.Draw(img)
    d.ellipse([196, 136, 316, 226], fill=(255, 175, 40), outline=(220, 110, 20), width=3)
    d.ellipse([214, 146, 260, 176], fill=(255, 220, 120))
    leaf(d, 270, 134, 26, (70, 150, 60), -0.2)
    fit_text(d, (256, 66), "망고 스무디", FONT_BHS, 58, 300, (180, 60, 10), (255, 255, 255), 4)
    fit_text(d, (256, 114), "MANGO", FONT_DH, 32, 200, (255, 255, 255))
    return d


def lab_water(img, d):
    img.paste(grad(LW, LH, (240, 250, 255), (180, 220, 250)))
    d = ImageDraw.Draw(img)
    for k in range(4):
        y = 170 + k * 18
        d.polygon([(0, y + 30), (90, y - 4), (190, y + 22), (300, y - 10), (400, y + 18), (LW, y), (LW, LH), (0, LH)],
                  fill=(60 + k * 30, 140 + k * 20, 220))
    fit_text(d, (256, 74), "맑은샘", FONT_BHS, 76, 280, (20, 80, 170), (255, 255, 255), 4)
    fit_text(d, (256, 128), "먹는샘물 500ml", FONT_JUA, 26, 260, (30, 90, 160))
    return d


def lab_ion(img, d):
    d.rectangle([0, 0, LW, LH], fill=(255, 255, 255))
    d.rectangle([0, 0, LW, 70], fill=(20, 90, 200))
    d.polygon([(0, 70), (LW, 40), (LW, 80), (0, 110)], fill=(20, 90, 200))
    fit_text(d, (256, 44), "AQUA ION", FONT_BHS, 52, 300, (255, 255, 255))
    fit_text(d, (256, 160), "이온워터", FONT_BHS, 64, 280, (20, 90, 200))
    fit_text(d, (256, 214), "수분  전해질 보충", FONT_JUA, 24, 240, (60, 110, 180))
    return d


def lab_greentea(img, d):
    img.paste(grad(LW, LH, (245, 250, 230), (200, 225, 160)))
    d = ImageDraw.Draw(img)
    for k in range(5):
        leaf(d, 70 + k * 92, 220, 30, (70 + k * 10, 140, 50), -0.4 + k * 0.2)
    d.ellipse([196, 36, 316, 156], outline=(60, 120, 40), width=4)
    fit_text(d, (256, 96), "녹차", FONT_BHS, 64, 110, (40, 100, 30))
    fit_text(d, (256, 180), "보성 녹차잎", FONT_JUA, 28, 220, (60, 100, 40))
    return d


def lab_barley(img, d):
    img.paste(grad(LW, LH, (240, 220, 180), (200, 160, 100)))
    d = ImageDraw.Draw(img)
    for k in range(5):
        cx = 60 + k * 100
        d.line([cx, 250, cx + 10, 150], fill=(150, 110, 40), width=4)
        for j in range(6):
            leaf(d, cx + 8 + (j % 2) * 10 - 5, 160 + j * 12, 9, (180, 130, 50), 1.2 if j % 2 else 1.9)
    fit_text(d, (256, 74), "구수한 보리차", FONT_BHS, 54, 320, (110, 60, 20), (255, 245, 220), 4)
    fit_text(d, (256, 124), "BARLEY TEA  0kcal", FONT_DH, 26, 260, (90, 50, 20))
    return d


def lab_aloe(img, d):
    d.rectangle([0, 0, LW, LH], fill=(250, 255, 245))
    for k in range(3):
        leaf(d, 140 + k * 116, 196, 60, (90, 170, 80), -1.2 + k * 0.4)
    d.rectangle([0, 0, LW, 26], fill=(70, 160, 70))
    fit_text(d, (256, 80), "알로에", FONT_BHS, 70, 260, (50, 130, 50), (255, 255, 255), 4)
    fit_text(d, (256, 132), "ALOE VERA 과육 듬뿍", FONT_DH, 26, 280, (60, 120, 60))
    return d


LABELS = [lab_cola, lab_cider, lab_coffee, lab_energy, lab_peach, lab_orange, lab_sikhye, lab_grape,
          lab_latte, lab_lemon, lab_mango, lab_water, lab_ion, lab_greentea, lab_barley, lab_aloe]


def labels_atlas():
    atlas = Image.new("RGB", (LW * 4, LH * 4), (255, 255, 255))
    for i, fn in enumerate(LABELS):
        img = Image.new("RGB", (LW, LH), (255, 255, 255))
        d = ImageDraw.Draw(img)
        fn(img, d)
        # 캔 인쇄 느낌: 아주 약한 세로 하이라이트 줄은 셰이더가 하므로 여기선 살짝 선명하게만
        img = img.filter(ImageFilter.UnsharpMask(1, 40, 2))
        atlas.paste(img, ((i % 4) * LW, (i // 4) * LH))
    save(atlas, "shop/vm_labels.png")


def header():
    w, h = 1024, 124
    img = grad(w, h, (20, 120, 230), (10, 60, 160))
    d = ImageDraw.Draw(img)
    for _ in range(26):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(4, 16)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(140, 200, 255), width=2)
    # 얼음 조각
    for cx in (90, 934):
        d.polygon([(cx - 32, 50), (cx, 24), (cx + 32, 44), (cx + 27, 96), (cx - 24, 102)], fill=(200, 235, 255), outline=(255, 255, 255))
    fit_text(d, (512, 54), "COOL DRINK", FONT_BHS, 84, 640, (255, 255, 255), (0, 40, 110), 5)
    fit_text(d, (512, 106), "언제나 시원한 음료  24시간", FONT_JUA, 30, 600, (210, 235, 255))
    save(img, "shop/vm_header.png")


def ad_panel():
    w, h = 1024, 640
    img = grad(w, h, (0, 150, 240), (0, 50, 140))
    d = ImageDraw.Draw(img)
    # 빛줄기
    for k in range(14):
        a = k / 14 * TAU
        d.polygon([(700, 330), (700 + math.cos(a) * 900, 330 + math.sin(a) * 900),
                   (700 + math.cos(a + 0.12) * 900, 330 + math.sin(a + 0.12) * 900)], fill=(30, 170, 250))
    img = img.filter(ImageFilter.GaussianBlur(6))
    d = ImageDraw.Draw(img)
    # 물 튀김
    for _ in range(60):
        a = rng.uniform(0, TAU)
        r = rng.uniform(140, 300)
        x, y = 700 + math.cos(a) * r, 330 + math.sin(a) * r * 0.8
        s = rng.uniform(6, 22)
        d.ellipse([x - s, y - s * 1.3, x + s, y + s * 1.3], fill=(220, 245, 255), outline=(255, 255, 255))
    # 큰 캔
    d.rounded_rectangle([600, 110, 800, 560], 30, fill=(200, 16, 32))
    d.rectangle([600, 130, 800, 145], fill=(190, 190, 195))
    d.rectangle([600, 530, 800, 545], fill=(190, 190, 195))
    d.rectangle([622, 150, 640, 520], fill=(235, 90, 100))
    fit_text(d, (700, 330), "COLAX", FONT_BHS, 70, 180, (255, 255, 255), (120, 0, 12), 3)
    # 얼음
    for cx, cy in ((560, 520), (830, 500), (580, 160)):
        d.polygon([(cx - 40, cy), (cx, cy - 38), (cx + 44, cy - 6), (cx + 30, cy + 40), (cx - 26, cy + 42)], fill=(210, 240, 255), outline=(255, 255, 255))
    fit_text(d, (270, 210), "얼음처럼", FONT_BHS, 100, 460, (255, 255, 255), (0, 40, 110), 6)
    fit_text(d, (270, 330), "시원하게!", FONT_BHS, 110, 460, (255, 240, 90), (0, 40, 110), 6)
    fit_text(d, (270, 450), "갈증엔 COOL DRINK", FONT_JUA, 46, 460, (220, 240, 255))
    save(img, "shop/vm_ad.png")


def side_wrap():
    w, h = 512, 1024
    img = grad(w, h, (10, 90, 200), (0, 40, 120))
    d = ImageDraw.Draw(img)
    for _ in range(90):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        s = rng.uniform(3, 14)
        d.ellipse([x - s, y - s * 1.2, x + s, y + s * 1.2], outline=(120, 190, 255), width=2)
    wave(d, w, 760, 30, (255, 255, 255), 18, 0.0, 1)
    wave(d, w, 800, 26, (30, 150, 240), 230, 1.0, 1)
    rot = Image.new("RGBA", (900, 220), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rot)
    fit_text(rd, (450, 110), "COOL DRINK", FONT_BHS, 170, 860, (255, 255, 255), (0, 40, 110), 6)
    rot = rot.rotate(90, expand=True)
    img.paste(rot, (int(w * 0.5 - rot.width * 0.5), 30), rot)
    save(img, "shop/vm_side.png")


if __name__ == "__main__":
    labels_atlas()
    header()
    ad_panel()
    side_wrap()
