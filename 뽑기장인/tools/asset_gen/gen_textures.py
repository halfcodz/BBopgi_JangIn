"""뽑기방 텍스처(기계 뒷판·간판·바닥·벽지·포스터·상품 인쇄) 생성."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "textures")
FONT_JUA = os.path.join(ROOT, "assets", "fonts", "Jua-Regular.ttf")
FONT_BHS = os.path.join(ROOT, "assets", "fonts", "BlackHanSans-Regular.ttf")
FONT_DH = os.path.join(ROOT, "assets", "fonts", "DoHyeon-Regular.ttf")
rng = np.random.default_rng(42)


def font(path, size):
    return ImageFont.truetype(path, size)


def save(img, name):
    p = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print("saved", name)


def heart(draw, cx, cy, s, fill):
    pts = []
    for i in range(60):
        tt = i / 60 * 2 * math.pi
        x = 16 * math.sin(tt) ** 3
        y = 13 * math.cos(tt) - 5 * math.cos(2 * tt) - 2 * math.cos(3 * tt) - math.cos(4 * tt)
        pts.append((cx + x * s / 16, cy - y * s / 16))
    draw.polygon(pts, fill=fill)


def star(draw, cx, cy, r, fill, rot=0.0):
    pts = []
    for i in range(10):
        a = rot + i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    draw.polygon(pts, fill=fill)


def outlined_text(draw, xy, text, fnt, fill, outline, width, anchor="mm"):
    draw.text(xy, text, font=fnt, fill=fill, anchor=anchor, stroke_width=width, stroke_fill=outline)


def machine_back(name, base, accent, title, shapes="heart"):
    W, H = 1024, 1024
    img = Image.new("RGB", (W, H), base)
    d = ImageDraw.Draw(img)
    # 대각선 줄무늬
    for i in range(-H, W, 90):
        d.polygon([(i, 0), (i + 45, 0), (i + 45 + H, H), (i + H, H)], fill=tuple(min(255, c + 10) for c in base))
    for k in range(70):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        s = rng.uniform(18, 46)
        col = accent[k % len(accent)]
        if shapes == "heart" and k % 3:
            heart(d, x, y, s, col)
        else:
            star(d, x, y, s * 0.8, col, rot=rng.uniform(0, 1))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    d = ImageDraw.Draw(img)
    outlined_text(d, (W / 2, H * 0.2), title, font(FONT_BHS, 150), (255, 255, 255), (60, 40, 70), 10)
    outlined_text(d, (W / 2, H * 0.36), "조이스틱으로 움직이고 버튼으로 집으세요!", font(FONT_JUA, 48), (255, 255, 255), (60, 40, 70), 5)
    save(img, f"machine/{name}.png")


def header(name, c1, c2):
    W, H = 1024, 256
    a = np.linspace(0, 1, W)[None, :, None]
    g = (np.array(c1)[None, None, :] * (1 - a) + np.array(c2)[None, None, :] * a)
    g = np.repeat(g, H, axis=0)
    yy = np.linspace(-1, 1, H)[:, None, None]
    g = g * (1 - 0.18 * yy ** 2)
    img = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for i in range(0, W, 64):
        d.ellipse([i + 20, 14, i + 44, 38], fill=(255, 250, 220))
        d.ellipse([i + 20, H - 38, i + 44, H - 14], fill=(255, 250, 220))
    save(img, f"machine/{name}.png")


def control_panel(name, base):
    W, H = 512, 256
    img = Image.new("RGB", (W, H), base)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([12, 12, W - 12, H - 12], 28, outline=(255, 255, 255), width=6)
    for k in range(18):
        star(d, rng.uniform(30, W - 30), rng.uniform(30, H - 30), rng.uniform(6, 14), (255, 255, 255))
    save(img, f"machine/{name}.png")


def floor_tiles():
    W = 1024
    n = 8
    s = W // n
    img = Image.new("RGB", (W, W))
    d = ImageDraw.Draw(img)
    for i in range(n):
        for j in range(n):
            c = (238, 236, 230) if (i + j) % 2 == 0 else (52, 50, 58)
            d.rectangle([i * s, j * s, (i + 1) * s - 1, (j + 1) * s - 1], fill=c)
    arr = np.asarray(img).astype(float)
    noise = rng.standard_normal((W, W))
    noise = np.asarray(Image.fromarray(((noise * 20) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(float) - 128
    arr += noise[..., None] * 0.35
    # 줄눈
    for k in range(n + 1):
        arr[max(k * s - 2, 0):k * s + 2, :, :] *= 0.75
        arr[:, max(k * s - 2, 0):k * s + 2, :] *= 0.75
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8))
    save(img, "shop/floor_tiles.png")
    # 거칠기(광택 얼룩)
    rough = np.asarray(Image.fromarray(((rng.standard_normal((256, 256)) * 30) + 110).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)))
    save(Image.fromarray(rough), "shop/floor_rough.png")


def wallpaper():
    W = 512
    img = Image.new("RGB", (W, W), (255, 226, 236))
    d = ImageDraw.Draw(img)
    for i in range(0, W, 64):
        d.rectangle([i, 0, i + 31, W], fill=(255, 236, 244))
    for k in range(10):
        x, y = (k * 97) % W, (k * 211) % W
        heart(d, x, y, 18, (255, 196, 214))
        star(d, (x + 256) % W, (y + 128) % W, 12, (255, 240, 180))
    save(img, "shop/wallpaper.png")


def ceiling():
    W = 512
    img = Image.new("RGB", (W, W), (236, 236, 240))
    arr = np.asarray(img).astype(float)
    arr += rng.standard_normal((W, W, 1)) * 6
    for k in range(0, W + 1, 256):
        arr[max(k - 3, 0):k + 3, :, :] = 180
        arr[:, max(k - 3, 0):k + 3, :] = 180
    save(Image.fromarray(arr.clip(0, 255).astype(np.uint8)), "shop/ceiling.png")


def prize_bed():
    W = 512
    base = np.array([60, 52, 120], float)
    arr = np.ones((W, W, 3)) * base
    n = rng.standard_normal((W, W))
    n = np.asarray(Image.fromarray(((n * 30) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(float) - 128
    arr += n[..., None] * 0.4
    save(Image.fromarray(arr.clip(0, 255).astype(np.uint8)), "machine/prize_bed.png")


def poster(name, bg, title, lines, deco="heart"):
    W, H = 600, 840
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    for k in range(26):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        col = (255, 255, 255)
        if deco == "heart":
            heart(d, x, y, rng.uniform(14, 30), (255, 255, 255))
        else:
            star(d, x, y, rng.uniform(10, 24), col)
    d.rounded_rectangle([30, 30, W - 30, H - 30], 30, outline=(255, 255, 255), width=8)
    outlined_text(d, (W / 2, 150), title, font(FONT_BHS, 92), (255, 255, 255), (60, 40, 70), 8)
    y = 300
    for ln in lines:
        outlined_text(d, (W / 2, y), ln, font(FONT_JUA, 46), (255, 255, 255), (60, 40, 70), 4)
        y += 80
    save(img, f"shop/{name}.png")


def figure_box():
    W, H = 512, 512
    img = Image.new("RGB", (W, H), (40, 90, 200))
    d = ImageDraw.Draw(img)
    for i in range(0, W, 40):
        d.line([(i, 0), (i - 200, H)], fill=(60, 110, 220), width=14)
    # 창(앞면) 영역 – 아틀라스 왼쪽 위 절반이 앞면
    d.rounded_rectangle([40, 60, 216, 300], 20, fill=(250, 240, 200))
    star(d, 128, 180, 70, (255, 200, 60))
    outlined_text(d, (128, 360), "럭키", font(FONT_BHS, 64), (255, 230, 80), (20, 30, 80), 5)
    outlined_text(d, (128, 430), "피규어", font(FONT_BHS, 54), (255, 255, 255), (20, 30, 80), 5)
    # 옆면/윗면(오른쪽 절반)
    d.rectangle([256, 0, W, H], fill=(230, 60, 80))
    outlined_text(d, (384, 128), "RANDOM", font(FONT_BHS, 54), (255, 255, 255), (80, 20, 30), 4)
    outlined_text(d, (384, 256), "?", font(FONT_BHS, 160), (255, 230, 80), (80, 20, 30), 6)
    outlined_text(d, (384, 400), "1/12", font(FONT_JUA, 60), (255, 255, 255), (80, 20, 30), 4)
    save(img, "prizes/figure_box.png")


def snack_bag():
    W, H = 512, 512
    img = Image.new("RGB", (W, H), (240, 70, 50))
    d = ImageDraw.Draw(img)
    for i in range(0, H, 36):
        d.rectangle([0, i, W, i + 12], fill=(250, 110, 60))
    d.ellipse([90, 140, 420, 380], fill=(255, 210, 60))
    outlined_text(d, (W / 2, 210), "바삭", font(FONT_BHS, 110), (255, 255, 255), (120, 30, 20), 8)
    outlined_text(d, (W / 2, 320), "콘칩", font(FONT_BHS, 90), (200, 40, 30), (255, 255, 255), 6)
    outlined_text(d, (W / 2, 450), "고소한 옥수수맛", font(FONT_JUA, 42), (255, 255, 255), (120, 30, 20), 4)
    save(img, "prizes/snack_bag.png")


def bills():
    # 게임용 가짜 지폐 아이콘(실제 지폐와 다른 단순 디자인)
    for val, col in (("1000", (120, 170, 230)), ("5000", (240, 170, 90)), ("10000", (140, 200, 130))):
        W, H = 320, 150
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([4, 4, W - 4, H - 4], 16, fill=col + (255,), outline=(255, 255, 255, 255), width=5)
        d.ellipse([20, 30, 110, 120], outline=(255, 255, 255, 255), width=5)
        d.text((65, 75), "뽑", font=font(FONT_BHS, 44), fill=(255, 255, 255, 255), anchor="mm")
        d.text((W - 22, H / 2), f"{int(val):,}", font=font(FONT_BHS, 54), fill=(255, 255, 255, 255), anchor="rm")
        save(img, f"ui/bill_{val}.png")


def _chibi_girl(d, cx, cy, s):
    # 오리지널 캐릭터: 분홍 머리 마법소녀(단순 도형)
    d.ellipse([cx - 70 * s, cy - 150 * s, cx + 70 * s, cy - 10 * s], fill=(255, 140, 190))  # 머리카락
    d.ellipse([cx - 55 * s, cy - 130 * s, cx + 55 * s, cy - 25 * s], fill=(255, 228, 210))  # 얼굴
    d.pieslice([cx - 70 * s, cy - 160 * s, cx + 70 * s, cy - 40 * s], 180, 360, fill=(255, 120, 180))  # 앞머리
    for sx in (-1, 1):
        d.ellipse([cx + sx * 22 * s - 11 * s, cy - 85 * s, cx + sx * 22 * s + 11 * s, cy - 60 * s], fill=(90, 60, 160))
        d.ellipse([cx + sx * 22 * s - 4 * s, cy - 82 * s, cx + sx * 22 * s + 3 * s, cy - 74 * s], fill=(255, 255, 255))
        d.ellipse([cx + sx * 85 * s - 25 * s, cy - 140 * s, cx + sx * 85 * s + 25 * s, cy - 90 * s], fill=(255, 140, 190))  # 양갈래
    d.arc([cx - 12 * s, cy - 58 * s, cx + 12 * s, cy - 45 * s], 20, 160, fill=(200, 80, 100), width=int(3 * s))
    d.polygon([(cx - 45 * s, cy - 15 * s), (cx + 45 * s, cy - 15 * s), (cx + 70 * s, cy + 110 * s), (cx - 70 * s, cy + 110 * s)], fill=(255, 255, 255))
    d.polygon([(cx - 70 * s, cy + 60 * s), (cx + 70 * s, cy + 60 * s), (cx + 85 * s, cy + 120 * s), (cx - 85 * s, cy + 120 * s)], fill=(255, 150, 200))
    d.line([(cx + 60 * s, cy - 10 * s), (cx + 120 * s, cy - 90 * s)], fill=(250, 210, 80), width=int(8 * s))
    star(d, cx + 125 * s, cy - 100 * s, 30 * s, (255, 220, 80))


def _robot(d, cx, cy, s):
    d.rounded_rectangle([cx - 60 * s, cy - 150 * s, cx + 60 * s, cy - 50 * s], 18 * s, fill=(90, 170, 255))
    d.rectangle([cx - 45 * s, cy - 125 * s, cx + 45 * s, cy - 80 * s], fill=(30, 40, 70))
    for sx in (-1, 1):
        d.ellipse([cx + sx * 22 * s - 12 * s, cy - 115 * s, cx + sx * 22 * s + 12 * s, cy - 91 * s], fill=(120, 255, 220))
    d.line([(cx, cy - 150 * s), (cx, cy - 185 * s)], fill=(200, 200, 210), width=int(6 * s))
    d.ellipse([cx - 10 * s, cy - 200 * s, cx + 10 * s, cy - 180 * s], fill=(255, 90, 90))
    d.rounded_rectangle([cx - 75 * s, cy - 45 * s, cx + 75 * s, cy + 80 * s], 20 * s, fill=(240, 240, 245))
    d.ellipse([cx - 25 * s, cy - 15 * s, cx + 25 * s, cy + 35 * s], fill=(255, 200, 60))
    for sx in (-1, 1):
        d.rounded_rectangle([cx + sx * 80 * s - 18 * s, cy - 40 * s, cx + sx * 80 * s + 18 * s, cy + 60 * s], 10 * s, fill=(90, 170, 255))
        d.rounded_rectangle([cx + sx * 35 * s - 22 * s, cy + 80 * s, cx + sx * 35 * s + 22 * s, cy + 130 * s], 8 * s, fill=(60, 120, 220))


def jp_figure(name, bg1, bg2, title, sub, draw_fn):
    W = 1024
    img = Image.new("RGB", (W, W), bg1)
    d = ImageDraw.Draw(img)
    # 앞면 (0,0)-(614,410)
    fx1, fy1 = 614, 410
    for i in range(0, fx1, 36):
        d.line([(i, 0), (i - 150, fy1)], fill=bg2, width=12)
    d.rounded_rectangle([200, 30, 590, 390], 24, fill=(250, 248, 255), outline=(255, 255, 255), width=6)
    draw_fn(d, 395, 250, 0.95)
    d.rectangle([0, 0, 190, fy1], fill=bg2)
    outlined_text(d, (95, 70), "PRIZE", font(FONT_BHS, 50), (255, 255, 255), (40, 20, 60), 5)
    outlined_text(d, (95, 120), "FIGURE", font(FONT_BHS, 42), (255, 230, 90), (40, 20, 60), 5)
    outlined_text(d, (95, 230), title, font(FONT_BHS, 32), (255, 255, 255), (40, 20, 60), 5)
    outlined_text(d, (95, 290), sub, font(FONT_JUA, 30), (255, 255, 255), (40, 20, 60), 4)
    outlined_text(d, (95, 370), "한정판", font(FONT_BHS, 40), (255, 80, 110), (255, 255, 255), 4)
    # 뒷면 (0,410)-(614,819)
    d.rectangle([0, 410, 614, 819], fill=bg2)
    draw_fn(d, 160, 680, 0.75)
    for i, ln in enumerate(["높이 약 18cm", "PVC/ABS 재질", "본 상품은 경품입니다", "만 15세 이상"]):
        outlined_text(d, (440, 500 + i * 60), ln, font(FONT_JUA, 34), (255, 255, 255), (40, 20, 60), 3)
    # 윗면/아랫면 (0,819)-(614,1024)
    d.rectangle([0, 819, 614, 1024], fill=bg1)
    outlined_text(d, (307, 921), title + " · PRIZE", font(FONT_BHS, 54), (255, 255, 255), (40, 20, 60), 5)
    # 옆면 (614,0)-(819,410), (819,0)-(1024,410)
    for x0 in (614, 819):
        d.rectangle([x0, 0, x0 + 205, 410], fill=bg2)
        outlined_text(d, (x0 + 102, 120), "PRIZE", font(FONT_BHS, 40), (255, 255, 255), (40, 20, 60), 4)
        star(d, x0 + 102, 250, 50, (255, 230, 90))
        outlined_text(d, (x0 + 102, 360), title, font(FONT_JUA, 30), (255, 255, 255), (40, 20, 60), 3)
    save(img, f"prizes/{name}.png")


if __name__ == "__main__":
    jp_figure("jp_figure_a", (255, 190, 220), (240, 90, 160), "마법소녀 미루", "반짝반짝 Ver.", _chibi_girl)
    jp_figure("jp_figure_b", (170, 210, 255), (50, 110, 220), "메카 보노", "출동 Ver.", _robot)
    machine_back("back_big", (255, 170, 200), [(255, 255, 255), (255, 120, 160), (255, 220, 120)], "뽑기장인", "heart")
    machine_back("back_small", (150, 205, 255), [(255, 255, 255), (255, 230, 120), (120, 170, 255)], "뽑기장인", "star")
    header("header_big", (255, 90, 150), (255, 160, 90))
    header("header_small", (70, 150, 255), (120, 220, 255))
    control_panel("panel_big", (240, 80, 140))
    control_panel("panel_small", (60, 140, 240))
    floor_tiles()
    wallpaper()
    ceiling()
    prize_bed()
    poster("poster_tip", (255, 140, 180), "뽑기 꿀팁", ["옆에서 깊이를 확인!", "인형 머리를 노려요", "팔·귀 틈에 발 넣기", "무리하지 말기 ♥"])
    poster("poster_new", (120, 180, 255), "신상 입고!", ["말랑 모찌볼", "펭귄 친구들", "공룡 삼총사", "매주 금요일 교체"], "star")
    poster("poster_rule", (255, 200, 90), "이용 안내", ["1,000원 지폐 사용", "교환기는 입구 옆", "상품은 배출구에서", "직원 호출: 사장님"], "star")
    figure_box()
    snack_bag()
    bills()
