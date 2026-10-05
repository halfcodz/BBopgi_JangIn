"""아이폰 앱 아이콘(1024x1024, 투명 없음 - 앱스토어 규칙) + 실행 화면 이미지.
실행: python gen_app_icon.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from gen_textures import FONT_BHS, ROOT, font

N = 1024


def bg():
    y, x = np.mgrid[0:N, 0:N] / N
    c1 = np.array([255, 120, 190], float)
    c2 = np.array([120, 70, 220], float)
    t = np.clip(y * 0.75 + x * 0.25, 0, 1)[..., None]
    arr = c1 * (1 - t) + c2 * t
    # 가운데가 살짝 밝게
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.45) ** 2)
    arr += (np.clip(0.55 - r, 0, 1) * 90)[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def bear(d, cx, cy, s):
    brown = (196, 140, 92)
    dark = (120, 80, 50)
    for ex in (-1, 1):
        d.ellipse([cx + ex * s * 0.62 - s * 0.28, cy - s * 0.78, cx + ex * s * 0.62 + s * 0.28, cy - s * 0.22], fill=brown)
        d.ellipse([cx + ex * s * 0.62 - s * 0.15, cy - s * 0.64, cx + ex * s * 0.62 + s * 0.15, cy - s * 0.36], fill=(240, 180, 170))
    d.ellipse([cx - s, cy - s * 0.62, cx + s, cy + s * 0.9], fill=brown)
    d.ellipse([cx - s * 0.42, cy + s * 0.08, cx + s * 0.42, cy + s * 0.62], fill=(240, 210, 175))
    for ex in (-1, 1):
        ex_ = cx + ex * s * 0.4
        d.ellipse([ex_ - s * 0.12, cy - s * 0.16, ex_ + s * 0.12, cy + s * 0.1], fill=(40, 25, 30))
        d.ellipse([ex_ - s * 0.05, cy - s * 0.12, ex_ + s * 0.02, cy - s * 0.04], fill=(255, 255, 255))
        d.ellipse([ex_ + ex * s * 0.08 - s * 0.12, cy + s * 0.18, ex_ + ex * s * 0.08 + s * 0.12, cy + s * 0.3], fill=(255, 150, 170))
    d.ellipse([cx - s * 0.12, cy + s * 0.14, cx + s * 0.12, cy + s * 0.3], fill=dark)
    d.arc([cx - s * 0.18, cy + s * 0.22, cx, cy + s * 0.44], 0, 160, fill=dark, width=max(3, int(s * 0.04)))
    d.arc([cx, cy + s * 0.22, cx + s * 0.18, cy + s * 0.44], 20, 180, fill=dark, width=max(3, int(s * 0.04)))


def claw(d, cx, top, bottom, s):
    metal = (235, 238, 245)
    shade = (150, 155, 175)
    d.rectangle([cx - 6, 0, cx + 6, top], fill=shade)
    d.rounded_rectangle([cx - s * 0.32, top, cx + s * 0.32, top + s * 0.36], radius=int(s * 0.12), fill=metal, outline=shade, width=6)
    for side in (-1, 1):
        pts = [(cx + side * s * 0.22, top + s * 0.3), (cx + side * s * 0.62, top + s * 0.75), (cx + side * s * 0.5, bottom), (cx + side * s * 0.34, bottom - s * 0.08)]
        d.line(pts, fill=metal, width=int(s * 0.1), joint="curve")
        d.line(pts, fill=shade, width=4)


def main():
    img = bg()
    d = ImageDraw.Draw(img)
    # 반짝이
    for (x, y, r) in [(150, 180, 26), (860, 230, 20), (880, 700, 30), (130, 640, 18), (800, 120, 14)]:
        d.polygon([(x, y - r * 2), (x + r * 0.5, y - r * 0.5), (x + r * 2, y), (x + r * 0.5, y + r * 0.5), (x, y + r * 2), (x - r * 0.5, y + r * 0.5), (x - r * 2, y), (x - r * 0.5, y - r * 0.5)], fill=(255, 250, 220))
    # 그림자 + 곰 + 집게
    sh = Image.new("L", (N, N), 0)
    ImageDraw.Draw(sh).ellipse([290, 840, 734, 920], fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    img.paste((70, 30, 90), (0, 0), sh)
    d = ImageDraw.Draw(img)
    bear(d, 512, 640, 250)
    claw(d, 512, 170, 470, 300)
    # 글씨
    f = font(FONT_BHS, 150)
    d.text((512, 930), "뽑기장인", font=f, fill=(255, 255, 255), anchor="mm", stroke_width=12, stroke_fill=(110, 40, 140))
    out = os.path.join(ROOT, "assets", "app")
    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "icon_1024.png"))
    print("saved assets/app/icon_1024.png")


if __name__ == "__main__":
    main()
