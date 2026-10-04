"""뽑기방 굿즈 모델: 말랑이(식빵·복숭아·냥발), 키캡 키링, 팝잇, 슬라임 컵.
버텍스 컬러 = [포인트 색 마스크, 세번째 색 마스크, AO] → goods.gdshader 가 색 조합(colorways)을 입힌다.
"""
import numpy as np

from sdf import (ellipsoid, length, round_box, smax, smin, sphere, surface_point)
from plush_models import Part, _sm, eyes_on, hull_points, thread_curve


def _convex(f, bmin, bmax, origin, count=44):
    pts = np.array(hull_points(f, bmin, bmax, voxel=0.0025, count=count)) - np.asarray(origin)
    return [{"type": "convex", "points": pts.tolist()}]


def _cyl(p, c, r, h, rr=0.0):
    q = p - np.asarray(c)
    d = np.stack([length(q[:, [0, 2]]) - (r - rr), np.abs(q[:, 1]) - (h / 2 - rr)], -1)
    return np.minimum(np.maximum(d[:, 0], d[:, 1]), 0) + length(np.maximum(d, 0)) - rr


def _face(f, c, front=(0, 0, 1), spread=0.32, eye_r=0.0035, mouth=True, up=0.1):
    acc = eyes_on(f, c, [(spread, up, 0.94), (-spread, up, 0.94)], eye_r)
    if mouth:
        m0, _ = surface_point(f, c, (0, up - 0.16, 1))
        acc.append(thread_curve(f, [m0 + [-0.004, 0.0015, 0], m0 + [-0.002, -0.0015, 0], m0, m0 + [0.002, -0.0015, 0], m0 + [0.004, 0.0015, 0]],
                                "mouth", radius=0.0007, samples=12))
    return acc


def _blush(p, centers, r0=0.004, r1=0.0075):
    b = np.zeros(len(p))
    for c in centers:
        b = np.maximum(b, 1 - _sm(length(p - np.asarray(c)), r0, r1))
    return b


# ======================================================================== 말랑이: 식빵
def squishy_bread():
    c = np.array([0, 0.03, 0])

    def body(p):
        d = round_box(p, (0, 0.027, 0), (0.036, 0.025, 0.021), 0.011)
        for sx in (1, -1):
            d = smin(d, ellipsoid(p, (0.019 * sx, 0.047, 0), (0.021, 0.016, 0.0205)), 0.01)
        return smax(d, -p[:, 1], 0.004)

    def mask(p, n):
        # 앞뒤 넓은 면 = 하얀 속살(main), 테두리 = 노릇한 껍질(accent), 볼터치 = accent2
        crumb = _sm(np.abs(n[:, 2]), 0.72, 0.9)
        crust = 1 - crumb
        blush = _blush(p, [(0.019, 0.028, 0.021), (-0.019, 0.028, 0.021)])
        return np.stack([crust, blush * 0.9], -1)

    bp = Part("body", body, (c - [0.05, 0.04, 0.035], c + [0.05, 0.05, 0.035]), c, 0.03, [], mask, faces=6000, voxel=0.0008)
    bp.shapes = _convex(body, c - [0.05, 0.04, 0.035], c + [0.05, 0.05, 0.035], c)
    bp.accessories = _face(body, c + [0, 0.004, 0], spread=0.3, up=0.12)
    return {"id": "squishy_bread", "parts": [bp], "joints": [], "material": "goods_soft", "height": 0.07}


# ======================================================================== 말랑이: 복숭아
def squishy_peach():
    c = np.array([0, 0.031, 0])

    def body(p):
        q = p - c
        d = sphere(p, c, 0.03)
        # 가운데 골(복숭아 홈)과 위쪽 뾰족한 꼭지
        d = d + 0.0022 * np.exp(-(q[:, 0] / 0.0045) ** 2) * _sm(q[:, 2], -0.01, 0.01)
        d = smin(d, ellipsoid(p, c + [0, 0.026, 0.004], (0.008, 0.012, 0.008)), 0.012)
        return smax(d, -(p[:, 1] - 0.002), 0.006)

    def mask(p, n):
        q = p - c
        top = _sm(q[:, 1] + q[:, 2] * 0.3, -0.005, 0.03)  # 위쪽이 진한 분홍(accent)
        blush = _blush(p, [(0.016, 0.027, 0.025), (-0.016, 0.027, 0.025)])
        return np.stack([top, blush * 0.9], -1)

    bp = Part("body", body, (c - 0.045, c + 0.05), c, 0.03, [], mask, faces=6000, voxel=0.0008)
    bp.shapes = _convex(body, c - 0.045, c + 0.05, c)
    acc = _face(body, c, spread=0.3, up=0.05)
    # 잎사귀(초록, 플라스틱 질감)
    from plush_models import sdf_blob_mesh
    leaf_c = c + [0.012, 0.03, -0.004]
    acc.append(sdf_blob_mesh("leaf", lambda p: ellipsoid(p, leaf_c, (0.011, 0.003, 0.006)), leaf_c, 0.014, (0.35, 0.7, 0.3), "plastic", faces=400))
    bp.accessories = acc
    return {"id": "squishy_peach", "parts": [bp], "joints": [], "material": "goods_soft", "height": 0.065}


# ======================================================================== 말랑이: 냥발(고양이 발바닥)
BEANS = [(-0.017, 0.028, 0.021), (-0.006, 0.033, 0.026), (0.006, 0.033, 0.026), (0.017, 0.028, 0.021)]


def squishy_paw():
    c = np.array([0, 0.022, 0])

    def body(p):
        d = ellipsoid(p, c, (0.036, 0.024, 0.032))
        d = smax(d, -(p[:, 1] - 0.001), 0.006)
        # 발가락 볼록 + 큰 젤리
        for b in BEANS:
            d = smin(d, ellipsoid(p, b, (0.0072, 0.0062, 0.0062)), 0.004)
        d = smin(d, ellipsoid(p, (0, 0.03, 0.002), (0.016, 0.011, 0.013)), 0.006)
        return d

    def mask(p, n):
        beans = np.zeros(len(p))
        for b in BEANS:
            beans = np.maximum(beans, 1 - _sm(ellipsoid(p, b, (0.0072, 0.0062, 0.0062)), -0.0003, 0.0012))
        beans = np.maximum(beans, 1 - _sm(ellipsoid(p, (0, 0.03, 0.002), (0.016, 0.011, 0.013)), -0.0003, 0.0015))
        return np.stack([beans, np.zeros(len(p))], -1)

    bp = Part("body", body, (c - [0.045, 0.03, 0.04], c + [0.045, 0.03, 0.045]), c, 0.03, [], mask, faces=6000, voxel=0.0008)
    bp.shapes = _convex(body, c - [0.045, 0.03, 0.04], c + [0.045, 0.03, 0.045], c)
    return {"id": "squishy_paw", "parts": [bp], "joints": [], "material": "goods_soft", "height": 0.05}


# ======================================================================== 키캡 키링 (왕 키캡)
def _keycap_shape(p, c):
    # 아래가 넓고 위가 좁은 SA/체리 비슷한 키캡 + 윗면 오목(디시)
    q = p - c
    t = np.clip(q[:, 1] / 0.026, 0, 1)
    half = 0.017 - 0.004 * t
    d = round_box(p * 1.0, c + [0, 0.013, 0], (0.017, 0.013, 0.017), 0.004)
    taper = np.maximum(np.abs(q[:, 0]), np.abs(q[:, 2])) - half
    d = np.maximum(d, taper - 0.0005)
    dish = sphere(p, c + [0, 0.026 + 0.06, 0], 0.062)
    d = smax(d, -dish, 0.002)
    return d


def keycap_heart():
    c = np.array([0, 0.0, 0])

    def heart2(x, z):
        # 윗면에 새긴 하트(2D)
        x = np.abs(x) / 0.0075
        z = (z + 0.002) / 0.0075
        return (x * x + z * z - 1) ** 3 - x * x * (-z) ** 3

    def body(p):
        d = _keycap_shape(p, c)
        # 하트 모양 살짝 볼록하게(돋을새김)
        on_top = _sm(p[:, 1], 0.018, 0.024)
        h = heart2(p[:, 0], -p[:, 2])
        d = d - 0.0007 * on_top * (1 - _sm(h, -0.02, 0.02))
        return d

    def mask(p, n):
        top = _sm(n[:, 1], 0.6, 0.85) * _sm(p[:, 1], 0.018, 0.022)
        h = heart2(p[:, 0], -p[:, 2])
        legend = top * (1 - _sm(h, -0.03, 0.03))
        side_band = (1 - _sm(p[:, 1], 0.003, 0.0045))  # 아래 테두리 띠
        return np.stack([side_band, legend], -1)

    bp = Part("body", body, (c - [0.022, 0.004, 0.022], c + [0.022, 0.032, 0.022]), c + [0, 0.013, 0], 0.03, [], mask, faces=5000, voxel=0.0005)
    bp.shapes = _convex(body, c - [0.022, 0.004, 0.022], c + [0.022, 0.032, 0.022], c + [0, 0.013, 0])
    return {"id": "keycap_heart", "parts": [bp], "joints": [], "material": "goods_plastic", "height": 0.03,
            "ring_top": [0.0, 0.03, -0.012]}


def keycap_cat():
    c = np.array([0, 0.0, 0])

    def body(p):
        d = _keycap_shape(p, c)
        for sx in (1, -1):
            ear = ellipsoid(p, c + [0.01 * sx, 0.028, -0.004], (0.0055, 0.008, 0.004))
            d = smin(d, ear, 0.003)
        return d

    def mask(p, n):
        inner_ear = np.zeros(len(p))
        for sx in (1, -1):
            inner_ear = np.maximum(inner_ear, (1 - _sm(length((p - (c + [0.01 * sx, 0.029, -0.0003])) * [1, 0.7, 1]), 0.002, 0.0035)))
        nose = _blush(p, [(0, 0.0215, 0.0165)], 0.0012, 0.0022)
        blush = _blush(p, [(0.008, 0.02, 0.017), (-0.008, 0.02, 0.017)], 0.0015, 0.003)
        side_band = (1 - _sm(p[:, 1], 0.003, 0.0045))
        return np.stack([side_band, np.maximum(np.maximum(inner_ear, nose), blush * 0.8)], -1)

    bp = Part("body", body, (c - [0.022, 0.004, 0.022], c + [0.022, 0.04, 0.022]), c + [0, 0.013, 0], 0.03, [], mask, faces=5500, voxel=0.0005)
    bp.shapes = _convex(body, c - [0.022, 0.004, 0.022], c + [0.022, 0.04, 0.022], c + [0, 0.013, 0])
    bp.accessories = eyes_on(body, c + [0, 0.016, 0], [(0.42, 0.28, 0.86), (-0.42, 0.28, 0.86)], 0.0022)
    return {"id": "keycap_cat", "parts": [bp], "joints": [], "material": "goods_plastic", "height": 0.035,
            "ring_top": [0.0, 0.032, -0.012]}


# ======================================================================== 팝잇(피젯 토이)
def popit():
    c = np.array([0, 0.006, 0])
    xs = np.linspace(-0.03, 0.03, 4)

    def body(p):
        d = round_box(p, c, (0.042, 0.005, 0.042), 0.005)
        bub = None
        for x in xs:
            for z in xs:
                b = sphere(p, (x, 0.008, z), 0.0085)
                bub = b if bub is None else np.minimum(bub, b)
        d = smin(d, bub, 0.002)
        return smax(d, -p[:, 1], 0.002)

    def mask(p, n):
        # 줄마다 색을 바꾼 무지개(main / accent / accent2 반복)
        row = np.clip(np.floor((p[:, 2] + 0.042) / 0.021), 0, 3)
        r = ((row == 1) | (row == 3)) * 1.0
        g = (row == 2) * 1.0
        return np.stack([r * (1 - g), g], -1)

    bp = Part("body", body, (c - [0.05, 0.01, 0.05], c + [0.05, 0.015, 0.05]), c, 0.03, [], mask, faces=7000, voxel=0.0007)
    bp.shapes = [{"type": "box", "center": [0, 0.0005, 0], "half": [0.043, 0.0068, 0.043], "rot": [0, 0, 0]}]
    return {"id": "popit", "parts": [bp], "joints": [], "material": "goods_silicone", "height": 0.018}


# ======================================================================== 슬라임 컵
def slime_cup():
    c = np.array([0, 0.025, 0])

    def body(p):
        cup = _cyl(p, c, 0.029, 0.05, 0.004)
        lid = _cyl(p, c + [0, 0.026, 0], 0.031, 0.008, 0.003)
        return np.minimum(cup, lid)

    def mask(p, n):
        lid = _sm(p[:, 1], 0.045, 0.047)
        band = _sm(p[:, 1], 0.017, 0.019) * (1 - _sm(p[:, 1], 0.033, 0.035)) * (1 - lid)
        return np.stack([lid, band], -1)

    bp = Part("body", body, (c - [0.04, 0.035, 0.04], c + [0.04, 0.04, 0.04]), c, 0.06, [], mask, faces=4000, voxel=0.0008)
    bp.shapes = [{"type": "cylinder", "center": [0, 0.002, 0], "radius": 0.031, "height": 0.058, "rot": [0, 0, 0]}]
    return {"id": "slime_cup", "parts": [bp], "joints": [], "material": "goods_plastic", "height": 0.06}


MODELS = {"squishy_bread": squishy_bread, "squishy_peach": squishy_peach, "squishy_paw": squishy_paw,
          "keycap_heart": keycap_heart, "keycap_cat": keycap_cat, "popit": popit, "slime_cup": slime_cup}


# ======================================================================== 전자기기 경품 상자(인쇄 상자)
GADGET_SIZES = {
    "gift_earbuds": (0.10, 0.11, 0.05),
    "gift_powerbank": (0.085, 0.14, 0.035),
    "gift_fan": (0.09, 0.17, 0.06),
    "gift_speaker": (0.11, 0.11, 0.10),
    "gift_lamp": (0.10, 0.13, 0.10),
}


def _gadget(model_id):
    from plush_models import JP_RECTS, MeshPart, _uv_box_atlas, box_shape

    def build():
        size = GADGET_SIZES[model_id]
        m = _uv_box_atlas(size, JP_RECTS)
        m.apply_translation([0, size[1] / 2, 0])
        p = MeshPart("box", m, [0, size[1] / 2, 0], 0.2, [box_shape([0, 0, 0], np.array(size) / 2)])
        return {"id": model_id, "parts": [p], "joints": [], "material": "printed", "height": size[1]}
    return build


for _gid in GADGET_SIZES:
    MODELS[_gid] = _gadget(_gid)
