"""
인형 모델 정의.
각 모델은 여러 '봉제 부위(part)'로 나뉘며, 부위마다
  - sdf: 부위 형상
  - mask: 버텍스 컬러에 굽는 영역 마스크 (R=포인트 원단, G=분홍/세번째 원단, B=AO)
  - origin: 물리 바디의 피벗(관절) 위치
  - shapes: 충돌 형상(구/캡슐/박스) – 래그돌 물리용
  - accessories: 눈/코/자수 실 등 부속 메시
를 가진다. joints 는 부위 사이 관절 정보.
"""
import numpy as np
from sdf import *  # noqa
import trimesh


def _sm(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


class Part:
    def __init__(self, name, sdf, bounds, origin, mass, shapes, mask=None,
                 faces=9000, voxel=0.0015):
        self.name = name
        self.sdf = sdf
        self.bounds = bounds
        self.origin = np.asarray(origin, float)
        self.mass = mass
        self.shapes = shapes
        self.mask = mask
        self.faces = faces
        self.voxel = voxel
        self.accessories = []  # (name, trimesh, kind)


def cap_shape(a, b, r):
    return {"type": "capsule", "a": list(map(float, a)), "b": list(map(float, b)), "radius": float(r)}


def sph_shape(c, r):
    return {"type": "sphere", "center": list(map(float, c)), "radius": float(r)}


def box_shape(c, half, rot_deg=(0, 0, 0)):
    return {"type": "box", "center": list(map(float, c)), "half": list(map(float, half)), "rot": list(map(float, rot_deg))}


def cyl_shape(c, r, h, rot_deg=(0, 0, 0)):
    return {"type": "cylinder", "center": list(map(float, c)), "radius": float(r), "height": float(h), "rot": list(map(float, rot_deg))}


def joint(a, b, pivot, swing=35, twist=20, stiffness=0.6, damping=0.05, axis=None):
    j = {"a": a, "b": b, "pivot": list(map(float, pivot)), "swing": swing, "twist": twist,
         "stiffness": stiffness, "damping": damping}
    if axis is not None:
        j["axis"] = list(map(float, axis))
    return j


# ======================================================================== 곰
def bear():
    torso_c = np.array([0, 0.088, -0.004])

    def torso(p):
        d = ellipsoid(p, torso_c, (0.074, 0.086, 0.066))
        belly = ellipsoid(p, (0, 0.075, 0.022), (0.058, 0.064, 0.05))
        d = smin(d, belly, 0.02)
        # 엉덩이 바닥을 살짝 눌러 앉은 자세
        d = smax(d, -(p[:, 1] - 0.006), 0.02)
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0)
        return d

    head_c = np.array([0, 0.214, 0.004])
    MUZ_C = np.array([0, 0.192, 0.06])
    MUZ_R = (0.04, 0.03, 0.034)

    def head_base(p):
        d = sphere(p, head_c, 0.07)
        cheeks = union(ellipsoid(p, (0.034, 0.198, 0.03), (0.045, 0.042, 0.042)),
                       ellipsoid(p, (-0.034, 0.198, 0.03), (0.045, 0.042, 0.042)))
        d = smin(d, cheeks, 0.025)
        muzzle = ellipsoid(p, MUZ_C, MUZ_R)
        d = smin(d, muzzle, 0.01)
        return d

    def ears(p):
        e1 = ellipsoid(p, (0.054, 0.271, -0.006), (0.027, 0.026, 0.013), rot_z(-25))
        e2 = ellipsoid(p, (-0.054, 0.271, -0.006), (0.027, 0.026, 0.013), rot_z(25))
        return union(e1, e2)

    def head(p):
        d = smin(head_base(p), ears(p), 0.008)
        # 머리 가운데 거싯 봉제선 + 주둥이 봉제선
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0, mask=_sm(p[:, 2], 0.03, 0.01))
        mz = ellipsoid(p, MUZ_C, MUZ_R)
        d = d + 0.0009 * np.exp(-(mz / 0.0016) ** 2) * np.exp(-(d / 0.004) ** 2)
        return d

    def head_mask(p, n):
        mz = ellipsoid(p, MUZ_C, MUZ_R)
        muzzle = 1.0 - _sm(mz, 0.0015, 0.0045)
        # 귀 안쪽(정면을 보는 면)
        ear_r = 1.0 - _sm(length(p - np.array([0.054, 0.268, 0.004])), 0.012, 0.02)
        ear_l = 1.0 - _sm(length(p - np.array([-0.054, 0.268, 0.004])), 0.012, 0.02)
        inner = np.maximum(ear_r, ear_l) * _sm(n[:, 2], 0.2, 0.6)
        return np.stack([np.maximum(muzzle, inner), np.zeros(len(p))], -1)

    def torso_mask(p, n):
        b = ellipsoid(p, (0, 0.07, 0.07), (0.04, 0.045, 0.02))
        belly = (1.0 - _sm(b, -0.004, 0.006)) * 0.0
        return np.stack([belly, np.zeros(len(p))], -1)

    arm_parts = []
    for side in (1, -1):
        sh = np.array([0.058 * side, 0.135, 0.008])
        paw = np.array([0.088 * side, 0.072, 0.048])

        def arm(p, sh=sh, paw=paw):
            d = round_cone(p, sh, paw, 0.021, 0.026)
            return d

        def arm_mask(p, n, paw=paw, sh=sh):
            axis = (paw - sh) / np.linalg.norm(paw - sh)
            t = (p - paw) @ axis
            pad = _sm(t, 0.004, 0.016) * _sm(n @ axis, 0.3, 0.7)
            return np.stack([pad, np.zeros(len(p))], -1)

        name = "arm_r" if side > 0 else "arm_l"
        lo = np.minimum(sh, paw) - 0.035
        hi = np.maximum(sh, paw) + 0.035
        part = Part(name, arm, (lo, hi), sh, 0.022,
                    [cap_shape(sh + (paw - sh) * 0.15 - sh, paw - sh, 0.022)], arm_mask, faces=2600)
        arm_parts.append(part)

    leg_parts = []
    for side in (1, -1):
        hip = np.array([0.042 * side, 0.042, 0.018])
        foot = np.array([0.054 * side, 0.03, 0.098])

        def leg(p, hip=hip, foot=foot):
            d = round_cone(p, hip, foot, 0.029, 0.031)
            # 발바닥 평평하게
            plane = (p - foot) @ np.array([0, 0, 1.0]) - 0.022
            d = smax(d, plane, 0.01)
            return d

        def leg_mask(p, n, foot=foot):
            sole = _sm(n[:, 2], 0.55, 0.85) * (1 - _sm(length((p - foot) * np.array([1, 1, 0])), 0.016, 0.022))
            return np.stack([sole, np.zeros(len(p))], -1)

        name = "leg_r" if side > 0 else "leg_l"
        lo = np.minimum(hip, foot) - 0.04
        hi = np.maximum(hip, foot) + 0.04
        part = Part(name, leg, (lo, hi), hip, 0.025,
                    [cap_shape((foot - hip) * 0.15, foot - hip - np.array([0, 0, 0.005]), 0.029)], leg_mask, faces=2600)
        leg_parts.append(part)

    torso_part = Part("torso", torso, (torso_c - [0.09, 0.1, 0.09], torso_c + [0.09, 0.1, 0.1]),
                      torso_c, 0.13,
                      [cap_shape(np.array([0, 0.03, 0.004]) - torso_c, np.array([0, 0.13, -0.004]) - torso_c, 0.068)],
                      torso_mask, faces=7000)
    neck = np.array([0, 0.158, 0.0])
    head_part = Part("head", head, (head_c - [0.095, 0.08, 0.08], head_c + [0.095, 0.09, 0.095]),
                     neck, 0.085,
                     [sph_shape(head_c - neck, 0.068),
                      sph_shape(MUZ_C - neck, 0.03),
                      sph_shape(np.array([0.054, 0.271, -0.006]) - neck, 0.02),
                      sph_shape(np.array([-0.054, 0.271, -0.006]) - neck, 0.02)],
                     head_mask, faces=11000)

    # 얼굴: 안전눈, 자수 코와 입
    eyes = []
    for side in (1, -1):
        pos, nrm = surface_point(head, head_c, (0.42 * side, 0.18, 0.88))
        eyes.append((("eye_r" if side > 0 else "eye_l"), dome(pos, nrm, 0.0072, iris=(0.12, 0.07, 0.04)), "eye"))
    nose_top, nn = surface_point(head, MUZ_C, (0, 0.38, 1))
    nose = ellipsoid  # 코는 SDF 로 따로 메시화
    nose_c = nose_top + nn * 0.002

    def nose_sdf(p):
        return ellipsoid(p, nose_c, (0.012, 0.0085, 0.006), rot_x(-20))
    nose_mesh, nose_n = mesh_sdf(nose_sdf, nose_c - 0.015, nose_c + 0.015, voxel=0.0006, target_faces=900)
    nose_mesh = finalize(nose_mesh, nose_n, np.tile([0.16, 0.09, 0.07], (len(nose_mesh.vertices), 1)))
    mouth_top, _ = surface_point(head, MUZ_C, (0, 0.02, 1))
    mouth_ctrl_r = [nose_top + np.array([0, -0.004, 0.0]), mouth_top + np.array([0, -0.004, 0]),
                    mouth_top + np.array([0.008, -0.011, -0.002]), mouth_top + np.array([0.016, -0.007, -0.006])]
    mouth_ctrl_l = [p * np.array([-1, 1, 1]) for p in mouth_ctrl_r]
    thread_col = (0.16, 0.09, 0.07)
    acc = eyes + [("nose", nose_mesh, "thread")]
    for i, ctrl in enumerate((mouth_ctrl_r, mouth_ctrl_l[1:])):
        pts = surface_curve(head, ctrl, samples=18)
        t = tube_along(pts, 0.0011, sides=6)
        acc.append((f"mouth_{i}", finalize(t, t.vertex_normals, np.tile(thread_col, (len(t.vertices), 1))), "thread"))
    head_part.accessories = acc

    parts = [torso_part, head_part] + arm_parts + leg_parts
    joints = [
        joint("torso", "head", neck, swing=28, twist=30, stiffness=0.9, damping=0.08),
        joint("torso", "arm_r", arm_parts[0].origin, swing=55, twist=25, stiffness=0.35),
        joint("torso", "arm_l", arm_parts[1].origin, swing=55, twist=25, stiffness=0.35),
        joint("torso", "leg_r", leg_parts[0].origin, swing=40, twist=20, stiffness=0.45),
        joint("torso", "leg_l", leg_parts[1].origin, swing=40, twist=20, stiffness=0.45),
    ]
    return {"id": "bear", "parts": parts, "joints": joints,
            "fabric": "minky", "height": 0.30}




# ======================================================================== 공용 얼굴 도우미
THREAD_DARK = (0.12, 0.07, 0.06)


def eyes_on(head_sdf, center, dirs, radius, iris=(0.12, 0.07, 0.04), color=(0.02, 0.02, 0.025)):
    out = []
    for i, dv in enumerate(dirs):
        pos, nrm = surface_point(head_sdf, center, dv)
        out.append((f"eye_{i}", dome(pos, nrm, radius, iris=iris, color=color), "eye"))
    return out


def thread_curve(head_sdf, ctrl, name, color=THREAD_DARK, radius=0.0011, samples=18):
    pts = surface_curve(head_sdf, ctrl, samples=samples)
    t = tube_along(pts, radius, sides=6)
    return (name, finalize(t, t.vertex_normals, np.tile(color, (len(t.vertices), 1))), "thread")


def sdf_blob_mesh(name, f, center, half, color, kind, voxel=0.0006, faces=900):
    m, n = mesh_sdf(f, np.asarray(center) - half, np.asarray(center) + half, voxel=voxel, target_faces=faces)
    return (name, finalize(m, n, np.tile(color, (len(m.vertices), 1))), kind)


def hull_points(f, bmin, bmax, voxel=0.004, count=48):
    """단일 바디 상품용 볼록 충돌 형상 점들."""
    m, _ = mesh_sdf(f, bmin, bmax, voxel=voxel, target_faces=2000, smooth_iters=2)
    h = m.convex_hull
    if len(h.vertices) > count:
        import fast_simplification as fs
        v, fc = fs.simplify(np.asarray(h.vertices, np.float32), np.asarray(h.faces, np.int32),
                            target_reduction=1 - count * 2 / len(h.faces))
        h = trimesh.Trimesh(v, fc).convex_hull
    return h.vertices.tolist()


# ======================================================================== 토끼 (귀가 펄럭이는 래그돌)
def bunny():
    torso_c = np.array([0, 0.078, -0.004])

    def torso(p):
        d = ellipsoid(p, torso_c, (0.064, 0.077, 0.058))
        d = smin(d, ellipsoid(p, (0, 0.066, 0.02), (0.05, 0.056, 0.044)), 0.018)
        tail = sphere(p, (0, 0.05, -0.064), 0.022)
        d = smin(d, tail, 0.008)
        d = smax(d, -(p[:, 1] - 0.005), 0.018)
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0)
        return d

    def torso_mask(p, n):
        tail = 1 - _sm(length(p - np.array([0, 0.05, -0.07])), 0.012, 0.02)
        return np.stack([tail, np.zeros(len(p))], -1)

    head_c = np.array([0, 0.188, 0.008])
    MUZ_C = np.array([0, 0.172, 0.055])

    def head(p):
        d = sphere(p, head_c, 0.064)
        cheeks = union(ellipsoid(p, (0.03, 0.172, 0.03), (0.042, 0.038, 0.04)),
                       ellipsoid(p, (-0.03, 0.172, 0.03), (0.042, 0.038, 0.04)))
        d = smin(d, cheeks, 0.022)
        d = smin(d, ellipsoid(p, MUZ_C, (0.03, 0.022, 0.024)), 0.012)
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0, mask=_sm(p[:, 2], 0.03, 0.01))
        return d

    def head_mask(p, n):
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - np.array([0.038 * sx, 0.168, 0.05])), 0.008, 0.014))
        return np.stack([np.zeros(len(p)), blush * 0.85], -1)

    parts = []
    neck = np.array([0, 0.138, 0.0])
    hp = Part("head", head, (head_c - [0.09, 0.08, 0.08], head_c + [0.09, 0.08, 0.09]), neck, 0.075,
              [sph_shape(head_c - neck, 0.062), sph_shape(MUZ_C - neck, 0.024)], head_mask, faces=9000)
    acc = eyes_on(head, head_c, [(0.42, 0.12, 0.9), (-0.42, 0.12, 0.9)], 0.0068)
    nose_top, nn = surface_point(head, MUZ_C, (0, 0.5, 1))
    nc = nose_top + nn * 0.0015

    def nose_sdf(p):
        return ellipsoid(p, nc, (0.0075, 0.0055, 0.004), rot_x(-25))
    acc.append(sdf_blob_mesh("nose", nose_sdf, nc, 0.012, (0.93, 0.52, 0.6), "thread"))
    mt, _ = surface_point(head, MUZ_C, (0, 0.0, 1))
    acc.append(thread_curve(head, [nose_top + [0, -0.004, 0], mt + [0, -0.006, 0]], "mouth_c"))
    acc.append(thread_curve(head, [mt + [0, -0.006, 0], mt + [0.007, -0.011, -0.002], mt + [0.013, -0.009, -0.005]], "mouth_r"))
    acc.append(thread_curve(head, [mt + [0, -0.006, 0], mt + [-0.007, -0.011, -0.002], mt + [-0.013, -0.009, -0.005]], "mouth_l"))
    hp.accessories = acc
    tp = Part("torso", torso, (torso_c - [0.08, 0.09, 0.1], torso_c + [0.08, 0.09, 0.09]), torso_c, 0.11,
              [cap_shape(np.array([0, 0.03, 0.005]) - torso_c, np.array([0, 0.115, -0.004]) - torso_c, 0.06)],
              torso_mask, faces=6000)
    parts += [tp, hp]
    joints = [joint("torso", "head", neck, swing=28, twist=30, stiffness=0.9, damping=0.08)]

    for side in (1, -1):
        sfx = "r" if side > 0 else "l"
        base = np.array([0.03 * side, 0.236, -0.004])
        tip = np.array([0.05 * side, 0.36, -0.012])
        axis = (tip - base) / np.linalg.norm(tip - base)

        def ear(p, base=base, tip=tip):
            mid = (base + tip) / 2
            ang = np.degrees(np.arctan2(tip[0] - base[0], tip[1] - base[1]))
            d = ellipsoid(p, mid, (0.026, 0.072, 0.011), rot_z(-ang))
            d = smin(d, sphere(p, base + [0, 0.01, 0], 0.016), 0.01)
            return d

        def ear_mask(p, n, base=base, tip=tip):
            mid = (base + tip) / 2
            ang = np.degrees(np.arctan2(tip[0] - base[0], tip[1] - base[1]))
            inner = ellipsoid(p - np.array([0, 0, 0.004]), mid + [0, 0.004, 0], (0.016, 0.058, 0.02), rot_z(-ang))
            m = (1 - _sm(inner, -0.002, 0.003)) * _sm(n[:, 2], 0.3, 0.7)
            return np.stack([np.zeros(len(p)), m], -1)
        lo = np.minimum(base, tip) - 0.035
        hi = np.maximum(base, tip) + 0.035
        ep = Part("ear_" + sfx, ear, (lo, hi), base, 0.008,
                  [cap_shape([0, 0.012, 0], tip - base - axis * 0.012, 0.014)], ear_mask, faces=2200)
        parts.append(ep)
        joints.append(joint("head", "ear_" + sfx, base, swing=50, twist=15, stiffness=0.25, damping=0.04))

        sh = np.array([0.05 * side, 0.118, 0.008])
        paw = np.array([0.072 * side, 0.062, 0.044])
        ap = Part("arm_" + sfx, (lambda p, sh=sh, paw=paw: round_cone(p, sh, paw, 0.018, 0.022)),
                  (np.minimum(sh, paw) - 0.03, np.maximum(sh, paw) + 0.03), sh, 0.016,
                  [cap_shape((paw - sh) * 0.15, paw - sh, 0.019)], None, faces=2200)
        parts.append(ap)
        joints.append(joint("torso", "arm_" + sfx, sh, swing=55, twist=25, stiffness=0.35))

        hip = np.array([0.036 * side, 0.036, 0.016])
        foot = np.array([0.044 * side, 0.026, 0.098])

        def leg(p, hip=hip, foot=foot):
            d = round_cone(p, hip, foot, 0.024, 0.028)
            return smax(d, (p[:, 2] - foot[2]) - 0.02, 0.01)

        def leg_mask(p, n, foot=foot):
            sole = _sm(n[:, 2], 0.55, 0.85) * (1 - _sm(length((p - foot) * np.array([1, 1, 0])), 0.013, 0.019))
            return np.stack([np.zeros(len(p)), sole * 0.9], -1)
        lp = Part("leg_" + sfx, leg, (np.minimum(hip, foot) - 0.035, np.maximum(hip, foot) + 0.035), hip, 0.02,
                  [cap_shape((foot - hip) * 0.15, foot - hip - np.array([0, 0, 0.004]), 0.024)], leg_mask, faces=2200)
        parts.append(lp)
        joints.append(joint("torso", "leg_" + sfx, hip, swing=40, twist=20, stiffness=0.45))
    return {"id": "bunny", "parts": parts, "joints": joints, "fabric": "velboa", "height": 0.36}


# ======================================================================== 펭귄
def penguin():
    c = np.array([0, 0.118, 0])

    def body(p):
        d = ellipsoid(p, c, (0.084, 0.118, 0.076))
        d = smin(d, ellipsoid(p, (0, 0.085, 0.012), (0.08, 0.08, 0.072)), 0.03)
        beak = ellipsoid(p, (0, 0.158, 0.078), (0.016, 0.009, 0.018), rot_x(10))
        d = smin(d, beak, 0.005)
        for sx in (1, -1):
            foot = ellipsoid(p, (0.032 * sx, 0.009, 0.06), (0.024, 0.009, 0.03), rot_y(-12 * sx))
            d = smin(d, foot, 0.006)
        d = smax(d, -(p[:, 1] - 0.0), 0.01)
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0, mask=_sm(-p[:, 2], -0.02, 0.01))
        return d

    def body_mask(p, n):
        belly_e = ellipsoid(p, (0, 0.11, 0.04), (0.06, 0.088, 0.06))
        face = ellipsoid(p, (0, 0.17, 0.045), (0.052, 0.04, 0.05))
        belly = 1 - _sm(np.minimum(belly_e, face), -0.002, 0.004)
        belly *= _sm(n[:, 2], -0.1, 0.25)
        beak = 1 - _sm(ellipsoid(p, (0, 0.158, 0.078), (0.016, 0.009, 0.018), rot_x(10)), 0.0005, 0.003)
        feet = _sm(-p[:, 1], -0.02, -0.016) * _sm(p[:, 2], 0.035, 0.045)
        org = np.maximum(beak, feet)
        return np.stack([belly * (1 - org), org], -1)

    bp = Part("body", body, (c - [0.11, 0.13, 0.1], c + [0.11, 0.13, 0.11]), c, 0.24,
              [cap_shape([0, -0.06, 0.004], [0, 0.04, 0], 0.074), sph_shape([0, -0.035, 0.012], 0.076)],
              body_mask, faces=11000)
    bp.accessories = eyes_on(body, c + [0, 0.05, 0], [(0.36, 0.08, 0.93), (-0.36, 0.08, 0.93)], 0.0072)
    blush = []
    parts = [bp]
    joints = []
    for side in (1, -1):
        sfx = "r" if side > 0 else "l"
        sh = np.array([0.074 * side, 0.15, 0.0])
        tip = np.array([0.1 * side, 0.07, 0.012])

        def flip(p, sh=sh, tip=tip):
            mid = (sh + tip) / 2
            ang = np.degrees(np.arctan2(tip[0] - sh[0], sh[1] - tip[1]))
            return ellipsoid(p, mid, (0.014, 0.052, 0.03), rot_z(ang))
        fp = Part("flip_" + sfx, flip, (np.minimum(sh, tip) - 0.04, np.maximum(sh, tip) + 0.04), sh, 0.012,
                  [cap_shape((tip - sh) * 0.12, (tip - sh) * 0.85, 0.014)], None, faces=1800)
        parts.append(fp)
        joints.append(joint("body", "flip_" + sfx, sh, swing=45, twist=15, stiffness=0.4))
    return {"id": "penguin", "parts": parts, "joints": joints, "fabric": "minky", "height": 0.24}


# ======================================================================== 공룡
def dino():
    tc = np.array([0, 0.085, 0.0])
    spike_pts = [np.array([0, 0.158, 0.03]), np.array([0, 0.163, -0.01]), np.array([0, 0.152, -0.05]),
                 np.array([0, 0.128, -0.085])]

    def spikes(p, pts, r=0.016):
        d = np.full(len(p), 1e3)
        for sp in pts:
            d = np.minimum(d, round_cone(p, sp - [0, 0.012, 0], sp + [0, 0.012, 0], r, 0.004))
        return d

    def torso(p):
        d = ellipsoid(p, tc, (0.072, 0.075, 0.098))
        d = smin(d, ellipsoid(p, (0, 0.07, 0.02), (0.064, 0.062, 0.08)), 0.02)
        for sx in (1, -1):
            for sz, ln in ((0.05, 0.02), (-0.05, -0.02)):
                d = smin(d, round_cone(p, (0.045 * sx, 0.05, sz), (0.05 * sx, 0.015, sz + ln * 0.4), 0.026, 0.024), 0.012)
        d = smin(d, spikes(p, spike_pts), 0.004)
        d = smax(d, -(p[:, 1] - 0.0), 0.008)
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0, mask=_sm(p[:, 1], 0.06, 0.04))
        return d

    def torso_mask(p, n):
        belly = (1 - _sm(ellipsoid(p, (0, 0.06, 0.06), (0.05, 0.05, 0.05)), -0.003, 0.004)) * _sm(n[:, 2], 0.0, 0.4)
        sp = 1 - _sm(spikes(p, spike_pts), 0.0005, 0.003)
        soles = _sm(-n[:, 1], 0.7, 0.9) * _sm(-p[:, 1], -0.006, -0.002)
        return np.stack([np.maximum(belly, soles), sp], -1)

    hc = np.array([0, 0.168, 0.1])

    def head(p):
        d = ellipsoid(p, hc, (0.056, 0.054, 0.062))
        d = smin(d, ellipsoid(p, hc + [0, -0.012, 0.035], (0.046, 0.036, 0.04)), 0.02)
        d = smin(d, spikes(p, [hc + [0, 0.052, -0.01]], r=0.013), 0.004)
        d = seam(d=d, p=p, normal=(1, 0, 0), offset=0.0, mask=_sm(p[:, 2], hc[2] - 0.0, hc[2] - 0.03))
        return d

    def head_mask(p, n):
        sp = 1 - _sm(spikes(p, [hc + [0, 0.052, -0.01]], r=0.013), 0.0005, 0.003)
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - (hc + [0.04 * sx, -0.018, 0.045])), 0.007, 0.012))
        return np.stack([np.zeros(len(p)), np.maximum(sp, blush * 0.8)], -1)

    neck = np.array([0, 0.14, 0.07])
    hp = Part("head", head, (hc - [0.08, 0.08, 0.09], hc + [0.08, 0.085, 0.1]), neck, 0.07,
              [sph_shape(hc - neck, 0.054), sph_shape(hc + [0, -0.012, 0.035] - neck, 0.036)], head_mask, faces=8000)
    acc = eyes_on(head, hc, [(0.5, 0.25, 0.83), (-0.5, 0.25, 0.83)], 0.0068)
    m0, _ = surface_point(head, hc + [0, -0.012, 0.035], (0, -0.25, 1))
    acc.append(thread_curve(head, [m0 + [0.016, 0.004, -0.008], m0 + [0.008, -0.003, -0.002], m0, m0 + [-0.008, -0.003, -0.002], m0 + [-0.016, 0.004, -0.008]], "smile", samples=24))
    for sx in (1, -1):
        nst, _ = surface_point(head, hc + [0, -0.012, 0.035], (0.18 * sx, 0.3, 1))
        acc.append(sdf_blob_mesh(f"nostril_{sx}", lambda p, c=nst: sphere(p, c, 0.0022), nst, 0.004, THREAD_DARK, "thread", voxel=0.0003, faces=200))
    hp.accessories = acc

    t1a, t1b = np.array([0, 0.07, -0.085]), np.array([0, 0.05, -0.17])
    t2b = np.array([0, 0.03, -0.25])
    tail1_sp = [np.array([0, 0.1, -0.12]), np.array([0, 0.085, -0.155])]
    tail2_sp = [np.array([0, 0.063, -0.195])]

    def tail1(p):
        return smin(round_cone(p, t1a, t1b, 0.046, 0.032), spikes(p, tail1_sp, r=0.012), 0.004)

    def tail2(p):
        return smin(round_cone(p, t1b, t2b, 0.032, 0.012), spikes(p, tail2_sp, r=0.009), 0.004)

    def tmask(pts, r):
        def f(p, n):
            sp = 1 - _sm(spikes(p, pts, r=r), 0.0005, 0.003)
            return np.stack([np.zeros(len(p)), sp], -1)
        return f

    tp = Part("torso", torso, (tc - [0.1, 0.1, 0.12], tc + [0.1, 0.1, 0.12]), tc, 0.17,
              [cap_shape([0, -0.005, -0.06], [0, -0.005, 0.05], 0.07),
               sph_shape([0.045, -0.055, 0.05], 0.025), sph_shape([-0.045, -0.055, 0.05], 0.025),
               sph_shape([0.045, -0.055, -0.05], 0.025), sph_shape([-0.045, -0.055, -0.05], 0.025)],
              torso_mask, faces=10000)
    p1 = Part("tail1", tail1, (np.minimum(t1a, t1b) - 0.06, np.maximum(t1a, t1b) + 0.06), t1a, 0.03,
              [cap_shape((t1b - t1a) * 0.25, t1b - t1a, 0.034)], tmask(tail1_sp, 0.012), faces=3000)
    p2 = Part("tail2", tail2, (np.minimum(t1b, t2b) - 0.04, np.maximum(t1b, t2b) + 0.04), t1b, 0.012,
              [cap_shape([0, 0, 0], (t2b - t1b) * 0.9, 0.018)], tmask(tail2_sp, 0.009), faces=2200)
    joints = [joint("torso", "head", neck, swing=25, twist=25, stiffness=0.9, damping=0.08),
              joint("torso", "tail1", t1a, swing=30, twist=15, stiffness=0.6),
              joint("tail1", "tail2", t1b, swing=35, twist=15, stiffness=0.5)]
    return {"id": "dino", "parts": [tp, hp, p1, p2], "joints": joints, "fabric": "minky", "height": 0.23}


# ======================================================================== 고양이 모찌 쿠션 (단일 바디, 잡기 어렵다)
def cat():
    c = np.array([0, 0.07, 0])

    def body(p):
        d = ellipsoid(p, c, (0.13, 0.072, 0.1))
        d = smin(d, ellipsoid(p, (0, 0.06, 0.0), (0.12, 0.06, 0.1)), 0.02)
        for sx in (1, -1):
            ear = round_cone(p, (0.07 * sx, 0.115, -0.01), (0.092 * sx, 0.158, -0.012), 0.024, 0.006)
            d = smin(d, ear, 0.02)
            paw = ellipsoid(p, (0.04 * sx, 0.016, 0.092), (0.022, 0.016, 0.018))
            d = smin(d, paw, 0.01)
        d = smax(d, -(p[:, 1] - 0.0), 0.02)
        d = seam(d=d, p=p, normal=(0, 1, 0.0), offset=0.03, mask=_sm(-p[:, 2], -0.2, -0.1) * 0 + 1)
        return d

    def body_mask(p, n):
        # 이마 줄무늬(삼색/치즈 무늬용) + 귀 안쪽 분홍
        stripe = np.zeros(len(p))
        for k, x in enumerate((-0.022, 0.0, 0.022)):
            sdist = ellipsoid(p, (x, 0.14, 0.01), (0.008, 0.012, 0.06))
            stripe = np.maximum(stripe, 1 - _sm(sdist, 0.0, 0.004))
        for sx in (1, -1):
            for z in (-0.04, 0.0):
                sd = ellipsoid(p, (0.12 * sx, 0.08, z), (0.02, 0.008, 0.012))
                stripe = np.maximum(stripe, 1 - _sm(sd, 0.0, 0.004))
        inner = np.zeros(len(p))
        for sx in (1, -1):
            inner = np.maximum(inner, (1 - _sm(length(p - np.array([0.08 * sx, 0.135, 0.004])), 0.008, 0.014)))
        inner *= _sm(n[:, 2], 0.2, 0.6)
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - np.array([0.058 * sx, 0.075, 0.092])), 0.008, 0.014))
        return np.stack([stripe, np.maximum(inner, blush * 0.8)], -1)

    bp = Part("body", body, (c - [0.15, 0.08, 0.12], c + [0.15, 0.11, 0.13]), c, 0.3,
              [{"type": "convex", "points": []}], body_mask, faces=12000)
    bp.shapes = [{"type": "convex", "points": (np.array(hull_points(body, c - [0.15, 0.08, 0.12], c + [0.15, 0.11, 0.13])) - c).tolist()}]
    acc = []
    # 눈: 웃는 눈(^ ^) 자수
    for sx in (1, -1):
        e0, _ = surface_point(body, c, (0.32 * sx, 0.12, 1))
        acc.append(thread_curve(body, [e0 + [-0.009, -0.002, 0], e0 + [0, 0.004, 0], e0 + [0.009, -0.002, 0]], f"eye_{sx}", radius=0.0016))
    nz, _ = surface_point(body, c, (0, 0.02, 1))
    acc.append(sdf_blob_mesh("nose", lambda p: ellipsoid(p, nz + [0, 0.0, 0.002], (0.006, 0.004, 0.003)), nz, 0.01, (0.95, 0.55, 0.62), "thread"))
    acc.append(thread_curve(body, [nz + [0, -0.004, 0], nz + [0.005, -0.009, 0], nz + [0.01, -0.006, 0]], "mouth_r"))
    acc.append(thread_curve(body, [nz + [0, -0.004, 0], nz + [-0.005, -0.009, 0], nz + [-0.01, -0.006, 0]], "mouth_l"))
    for sx in (1, -1):
        for dy in (0.0, -0.007):
            w0 = nz + [0.03 * sx, dy, -0.004]
            acc.append(thread_curve(body, [w0, w0 + [0.014 * sx, 0.002 + dy * 0.3, -0.005]], f"whisker_{sx}_{dy}", radius=0.0007, samples=8))
    bp.accessories = acc
    return {"id": "cat", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.15}


# ======================================================================== 작은 기계용: 병아리
def chick():
    c = np.array([0, 0.045, 0])

    def body(p):
        d = ellipsoid(p, c, (0.043, 0.042, 0.04))
        d = smin(d, sphere(p, (0, 0.082, 0.008), 0.03), 0.02)
        for sx in (1, -1):
            d = smin(d, ellipsoid(p, (0.04 * sx, 0.045, -0.004), (0.01, 0.022, 0.018), rot_z(-25 * sx)), 0.008)
        tuft = round_cone(p, (0, 0.108, 0.004), (0.004, 0.122, -0.004), 0.006, 0.002)
        d = smin(d, tuft, 0.004)
        beak = ellipsoid(p, (0, 0.082, 0.039), (0.008, 0.005, 0.009))
        d = smin(d, beak, 0.002)
        for sx in (1, -1):
            d = smin(d, ellipsoid(p, (0.014 * sx, 0.004, 0.024), (0.009, 0.004, 0.012)), 0.004)
        d = smax(d, -(p[:, 1]), 0.006)
        return d

    def mask(p, n):
        beak = 1 - _sm(ellipsoid(p, (0, 0.082, 0.039), (0.008, 0.005, 0.009)), 0.0004, 0.0018)
        feet = _sm(-p[:, 1], -0.009, -0.006) * _sm(p[:, 2], 0.012, 0.016)
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - np.array([0.021 * sx, 0.076, 0.026])), 0.004, 0.007))
        return np.stack([np.maximum(beak, feet), blush * 0.85], -1)

    bp = Part("body", body, (c - [0.06, 0.05, 0.05], c + [0.06, 0.085, 0.06]), c, 0.05,
              [], mask, faces=7000, voxel=0.0008)
    bp.shapes = [sph_shape([0, 0, 0], 0.041), sph_shape([0, 0.037, 0.008], 0.029)]
    bp.accessories = eyes_on(body, (0, 0.082, 0.008), [(0.5, 0.2, 0.84), (-0.5, 0.2, 0.84)], 0.004)
    return {"id": "chick", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.12}


# ======================================================================== 작은 기계용: 오리
def duck():
    c = np.array([0, 0.04, 0])

    def body(p):
        d = ellipsoid(p, c, (0.042, 0.036, 0.05))
        d = smin(d, round_cone(p, (0, 0.04, -0.04), (0, 0.062, -0.058), 0.014, 0.006), 0.012)
        d = smin(d, sphere(p, (0, 0.088, 0.02), 0.03), 0.016)
        bill = ellipsoid(p, (0, 0.082, 0.052), (0.016, 0.0065, 0.016))
        d = smin(d, bill, 0.003)
        for sx in (1, -1):
            d = smin(d, ellipsoid(p, (0.04 * sx, 0.045, -0.004), (0.01, 0.018, 0.028), rot_x(15)), 0.006)
        d = smax(d, -(p[:, 1]), 0.006)
        return d

    def mask(p, n):
        bill = 1 - _sm(ellipsoid(p, (0, 0.082, 0.052), (0.016, 0.0065, 0.016)), 0.0004, 0.0018)
        return np.stack([bill, np.zeros(len(p))], -1)

    bp = Part("body", body, (c - [0.06, 0.05, 0.075], c + [0.06, 0.085, 0.07]), c, 0.05, [], mask, faces=7000, voxel=0.0008)
    bp.shapes = [cap_shape([0, 0, -0.02], [0, 0, 0.012], 0.036), sph_shape([0, 0.048, 0.02], 0.029)]
    bp.accessories = eyes_on(body, (0, 0.088, 0.02), [(0.62, 0.22, 0.75), (-0.62, 0.22, 0.75)], 0.004)
    return {"id": "duck", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.12}


# ======================================================================== 작은 기계용: 말랑 모찌볼
def mochi():
    c = np.array([0, 0.034, 0])

    def body(p):
        d = ellipsoid(p, c, (0.04, 0.034, 0.038))
        d = smax(d, -(p[:, 1]), 0.012)
        return d

    def mask(p, n):
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - np.array([0.021 * sx, 0.03, 0.033])), 0.004, 0.0075))
        return np.stack([np.zeros(len(p)), blush * 0.9], -1)

    bp = Part("body", body, (c - 0.05, c + 0.05), c, 0.04, [], mask, faces=5000, voxel=0.0008)
    bp.shapes = [{"type": "convex", "points": (np.array(hull_points(body, c - 0.05, c + 0.05, voxel=0.003, count=40)) - c).tolist()}]
    acc = eyes_on(body, c, [(0.32, 0.12, 0.94), (-0.32, 0.12, 0.94)], 0.0035)
    m0, _ = surface_point(body, c, (0, -0.02, 1))
    acc.append(thread_curve(body, [m0 + [-0.004, 0.001, 0], m0 + [-0.002, -0.002, 0], m0, m0 + [0.002, -0.002, 0], m0 + [0.004, 0.001, 0]], "mouth", radius=0.0008, samples=12))
    bp.accessories = acc
    return {"id": "mochi", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.07}


MODELS = {"bear": bear, "bunny": bunny, "penguin": penguin, "dino": dino, "cat": cat,
          "chick": chick, "duck": duck, "mochi": mochi}


# ======================================================================== 딱딱한 상품(상자/과자/캡슐)
def _uv_box(size):
    """UV 아틀라스 상자: 앞면=왼쪽 절반, 나머지 면=오른쪽 절반."""
    hx, hy, hz = np.asarray(size) / 2
    faces = [
        # (normal, corners(ccw from outside), uv rect)
        ((0, 0, 1), [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)], (0.0, 0.0, 0.5, 1.0)),
        ((0, 0, -1), [(hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)], (0.5, 0.0, 1.0, 1.0)),
        ((1, 0, 0), [(hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz)], (0.5, 0.0, 1.0, 1.0)),
        ((-1, 0, 0), [(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)], (0.5, 0.0, 1.0, 1.0)),
        ((0, 1, 0), [(-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz)], (0.5, 0.0, 1.0, 0.35)),
        ((0, -1, 0), [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)], (0.5, 0.65, 1.0, 1.0)),
    ]
    V, N, UV, F = [], [], [], []
    for nrm, cs, (u0, v0, u1, v1) in faces:
        b = len(V)
        uvs = [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)]
        for c, uv in zip(cs, uvs):
            V.append(c)
            N.append(nrm)
            UV.append(uv)
        F += [[b, b + 1, b + 2], [b, b + 2, b + 3]]
    m = trimesh.Trimesh(np.array(V), np.array(F), vertex_normals=np.array(N), process=False)
    m.visual = trimesh.visual.TextureVisuals(uv=np.array(UV))
    return m


class MeshPart(Part):
    """SDF 대신 미리 만든 메시를 쓰는 부위."""
    def __init__(self, name, mesh, origin, mass, shapes):
        super().__init__(name, None, None, origin, mass, shapes)
        self.mesh = mesh


def figure_box():
    size = (0.11, 0.16, 0.075)
    m = _uv_box(size)
    m.apply_translation([0, size[1] / 2, 0])
    p = MeshPart("box", m, [0, size[1] / 2, 0], 0.2, [box_shape([0, 0, 0], np.array(size) / 2)])
    return {"id": "figure_box", "parts": [p], "joints": [], "material": "printed", "height": size[1]}


def snack_bag():
    W, H, T = 0.13, 0.17, 0.045

    def bag(p):
        q = p - np.array([0, H / 2, 0])
        # 가운데가 부푼 베개 모양
        y = np.clip(np.abs(q[:, 1]) / (H / 2), 0, 1)
        x = np.clip(np.abs(q[:, 0]) / (W / 2), 0, 1)
        puff = T / 2 * np.sqrt(np.clip(1 - y ** 6, 0, 1)) * np.sqrt(np.clip(1 - x ** 4, 0, 1)) + 0.0015
        dz = np.abs(q[:, 2]) - puff
        dx = np.abs(q[:, 0]) - W / 2
        dy = np.abs(q[:, 1]) - H / 2
        d = np.maximum(np.maximum(dx, dy), dz)
        # 위아래 톱니 실링
        crimp = 0.0007 * np.sin(q[:, 0] * 2 * np.pi / 0.006) * _sm(np.abs(q[:, 1]), H / 2 - 0.015, H / 2 - 0.01)
        return d + crimp

    mesh, n = mesh_sdf(bag, [-W / 2 - 0.01, -0.01, -T], [W / 2 + 0.01, H + 0.01, T], voxel=0.0012, target_faces=5000, smooth_iters=3)
    v = np.asarray(mesh.vertices)
    u = (v[:, 0] / W + 0.5)
    u = np.where(v[:, 2] >= 0, u, 1 - u)
    uv = np.stack([u, v[:, 1] / H], -1)
    m = trimesh.Trimesh(v, mesh.faces, vertex_normals=n, process=False)
    m.visual = trimesh.visual.TextureVisuals(uv=uv)
    hull = (np.array(hull_points(bag, [-W / 2 - 0.01, -0.01, -T], [W / 2 + 0.01, H + 0.01, T], voxel=0.004, count=40)) - [0, H / 2, 0]).tolist()
    p = MeshPart("bag", m, [0, H / 2, 0], 0.06, [{"type": "convex", "points": hull}])
    return {"id": "snack_bag", "parts": [p], "joints": [], "material": "foil", "height": H}


def capsule():
    r = 0.032
    s = trimesh.creation.icosphere(subdivisions=4, radius=r)
    v = np.asarray(s.vertices)
    vn = v / r
    cols = np.ones((len(v), 4))
    bottom = v[:, 1] < 0
    cols[bottom, 3] = 0.32
    ring = np.abs(v[:, 1]) < 0.0025
    cols[ring] = [0.92, 0.92, 0.92, 1.0]
    m = finalize(trimesh.Trimesh(v + [0, r, 0], s.faces, process=False), vn, cols)
    # 캡슐 속 작은 장난감
    inner = trimesh.creation.icosphere(subdivisions=2, radius=r * 0.55)
    iv = np.asarray(inner.vertices) * [1.0, 0.8, 1.0] + [0, r * 0.75, 0]
    im = finalize(trimesh.Trimesh(iv, inner.faces, process=False), np.asarray(inner.vertices) / (r * 0.55), np.tile([1, 1, 1], (len(iv), 1)))
    p = MeshPart("shell", m, [0, r, 0], 0.03, [sph_shape([0, 0, 0], r)])
    p.accessories = [("toy", im, "tint")]
    return {"id": "capsule", "parts": [p], "joints": [], "material": "capsule", "height": 2 * r}


MODELS.update({"figure_box": figure_box, "snack_bag": snack_bag, "capsule": capsule})


# ======================================================================== 판다 (곰 몸을 쓰고 무늬만 다르게)
def panda():
    spec = bear()
    head_c = np.array([0, 0.214, 0.004])
    patches = []
    for side in (1, -1):
        d = np.array([0.42 * side, 0.16, 0.88])
        d /= np.linalg.norm(d)
        patches.append(head_c + d * 0.066)

    def head_mask(p, n):
        ears = np.zeros(len(p))
        for sx in (1, -1):
            ears = np.maximum(ears, 1 - _sm(length(p - np.array([0.054 * sx, 0.271, -0.006])), 0.026, 0.032))
        eyep = np.zeros(len(p))
        for c in patches:
            q = (p - c) @ rot_z(-25 if c[0] > 0 else 25)
            e = length(q / np.array([0.017, 0.022, 0.02]))
            eyep = np.maximum(eyep, 1 - _sm(e, 0.9, 1.15))
        return np.stack([np.maximum(ears, eyep), np.zeros(len(p))], -1)

    def limb_mask(p, n):
        return np.stack([np.ones(len(p)), np.zeros(len(p))], -1)

    def torso_mask(p, n):
        # 어깨를 두르는 검은 띠
        band = (1 - _sm(np.abs(p[:, 1] - 0.14), 0.018, 0.03)) * _sm(np.abs(p[:, 0]), 0.02, 0.05)
        return np.stack([band, np.zeros(len(p))], -1)

    for part in spec["parts"]:
        if part.name == "head":
            part.mask = head_mask
            # 판다는 주둥이도 흰색, 코는 검정
        elif part.name.startswith("arm") or part.name.startswith("leg"):
            part.mask = limb_mask
        elif part.name == "torso":
            part.mask = torso_mask
    spec["id"] = "panda"
    return spec


# ======================================================================== 시바견 (앉은 자세, 말린 꼬리)
def shiba():
    tc = np.array([0, 0.082, -0.01])

    def torso(p):
        d = ellipsoid(p, tc, (0.064, 0.082, 0.07))
        d = smin(d, ellipsoid(p, (0, 0.07, 0.022), (0.052, 0.06, 0.05)), 0.02)
        # 말린 꼬리(원환 일부)
        tail = torus(p, (0, 0.12, -0.08), 0.026, 0.014, axis="x")
        tail = smax(tail, -(p[:, 1] - 0.1), 0.01)
        d = smin(d, tail, 0.012)
        for sx in (1, -1):
            d = smin(d, round_cone(p, (0.035 * sx, 0.03, 0.03), (0.035 * sx, 0.012, 0.085), 0.02, 0.019), 0.01)
        d = smax(d, -(p[:, 1] - 0.004), 0.015)
        return seam(d=d, p=p, normal=(1, 0, 0), offset=0.0)

    def torso_mask(p, n):
        chest = (1 - _sm(ellipsoid(p, (0, 0.08, 0.05), (0.04, 0.06, 0.04)), -0.004, 0.006)) * _sm(n[:, 2], -0.1, 0.4)
        tail_under = (1 - _sm(length(p - np.array([0, 0.13, -0.11])), 0.012, 0.02))
        paws = _sm(p[:, 2], 0.07, 0.085) * (1 - _sm(p[:, 1], 0.03, 0.04))
        return np.stack([np.maximum(np.maximum(chest, tail_under), paws), np.zeros(len(p))], -1)

    hc = np.array([0, 0.2, 0.005])
    MZ = np.array([0, 0.185, 0.058])

    def head(p):
        d = ellipsoid(p, hc, (0.068, 0.06, 0.06))
        d = smin(d, ellipsoid(p, MZ, (0.032, 0.025, 0.035)), 0.016)
        for sx in (1, -1):
            ear = round_cone(p, (0.036 * sx, 0.245, -0.004), (0.05 * sx, 0.285, -0.006), 0.022, 0.006)
            ear = smax(ear, -(p[:, 2] + 0.016), 0.004)
            ear = smax(ear, p[:, 2] - 0.012, 0.004)
            d = smin(d, ear, 0.01)
        return seam(d=d, p=p, normal=(1, 0, 0), offset=0.0, mask=_sm(p[:, 2], 0.02, 0.0))

    def head_mask(p, n):
        mz = 1 - _sm(ellipsoid(p, MZ + [0, -0.008, -0.004], (0.036, 0.024, 0.04)), -0.002, 0.004)
        cheeks = np.zeros(len(p))
        for sx in (1, -1):
            cheeks = np.maximum(cheeks, 1 - _sm(length(p - np.array([0.042 * sx, 0.175, 0.04])), 0.012, 0.02))
            # 눈썹 점
            cheeks = np.maximum(cheeks, (1 - _sm(length(p - np.array([0.025 * sx, 0.228, 0.055])), 0.004, 0.007)))
        inner_ear = np.zeros(len(p))
        for sx in (1, -1):
            inner_ear = np.maximum(inner_ear, (1 - _sm(length((p - np.array([0.043 * sx, 0.262, 0.0])) * [1, 0.7, 1]), 0.008, 0.013)) * _sm(n[:, 2], 0.3, 0.7))
        return np.stack([np.maximum(np.maximum(mz, cheeks), inner_ear), np.zeros(len(p))], -1)

    neck = np.array([0, 0.155, 0.0])
    hp = Part("head", head, (hc - [0.09, 0.08, 0.09], hc + [0.09, 0.1, 0.1]), neck, 0.08,
              [sph_shape(hc - neck, 0.06), sph_shape(MZ - neck, 0.027)], head_mask, faces=9000)
    acc = eyes_on(head, hc, [(0.42, 0.16, 0.89), (-0.42, 0.16, 0.89)], 0.0065)
    nt, nn = surface_point(head, MZ, (0, 0.3, 1))
    nc = nt + nn * 0.0015
    acc.append(sdf_blob_mesh("nose", lambda p: ellipsoid(p, nc, (0.011, 0.0075, 0.006), rot_x(-20)), nc, 0.014, THREAD_DARK, "eye"))
    mt, _ = surface_point(head, MZ, (0, -0.15, 1))
    acc.append(thread_curve(head, [nt + [0, -0.006, 0], mt + [0, -0.002, 0]], "mouth_c"))
    acc.append(thread_curve(head, [mt + [0, -0.002, 0], mt + [0.009, -0.006, -0.003], mt + [0.016, -0.002, -0.007]], "mouth_r"))
    acc.append(thread_curve(head, [mt + [0, -0.002, 0], mt + [-0.009, -0.006, -0.003], mt + [-0.016, -0.002, -0.007]], "mouth_l"))
    hp.accessories = acc
    tp = Part("torso", torso, (tc - [0.09, 0.09, 0.13], tc + [0.09, 0.1, 0.12]), tc, 0.14,
              [cap_shape([0, -0.05, 0.01], [0, 0.04, 0.0], 0.062), sph_shape([0, 0.04, -0.075], 0.03)], torso_mask, faces=8000)
    parts = [tp, hp]
    joints = [joint("torso", "head", neck, swing=28, twist=30, stiffness=0.9, damping=0.08)]
    for side in (1, -1):
        sh = np.array([0.045 * side, 0.12, 0.03])
        paw = np.array([0.05 * side, 0.03, 0.07])
        def arm(p, sh=sh, paw=paw):
            return round_cone(p, sh, paw, 0.019, 0.02)
        def arm_mask(p, n, paw=paw):
            return np.stack([1 - _sm(p[:, 1], 0.045, 0.06), np.zeros(len(p))], -1)
        nm = "arm_r" if side > 0 else "arm_l"
        parts.append(Part(nm, arm, (np.minimum(sh, paw) - 0.03, np.maximum(sh, paw) + 0.03), sh, 0.02,
                          [cap_shape((paw - sh) * 0.2, paw - sh, 0.018)], arm_mask, faces=2000))
        joints.append(joint("torso", nm, sh, swing=40, twist=20, stiffness=0.5))
    return {"id": "shiba", "parts": parts, "joints": joints, "fabric": "minky", "height": 0.29}


# ======================================================================== 상어 (길쭉한 몸 + 꼬리 관절)
def shark():
    def body(p):
        d = round_cone(p, (0, 0.06, 0.11), (0, 0.065, -0.07), 0.052, 0.058)
        d = smin(d, ellipsoid(p, (0, 0.06, 0.12), (0.05, 0.045, 0.06)), 0.03)
        fin = ellipsoid(p, (0, 0.13, -0.01), (0.008, 0.045, 0.03), rot_x(-25))
        fin = smax(fin, -(p[:, 1] - 0.1), 0.006)
        d = smin(d, fin, 0.012)
        for sx in (1, -1):
            pf = ellipsoid(p, (0.06 * sx, 0.035, 0.04), (0.04, 0.008, 0.026), rot_z(20 * sx) @ rot_y(-25 * sx))
            d = smin(d, pf, 0.01)
        d = seam(d=d, p=p, normal=(0, 1, 0), offset=0.055, mask=_sm(p[:, 2], -0.1, -0.09))
        return d

    def body_mask(p, n):
        belly = _sm(-n[:, 1], -0.25, 0.25) * _sm(-(p[:, 1] - 0.06), -0.01, 0.01)
        mouth = (1 - _sm(ellipsoid(p, (0, 0.04, 0.16), (0.03, 0.006, 0.02)), 0.0, 0.003))
        return np.stack([belly, mouth * 0.95], -1)

    def tail(p):
        d = round_cone(p, (0, 0.065, -0.07), (0, 0.075, -0.18), 0.05, 0.016)
        up = ellipsoid(p, (0, 0.11, -0.2), (0.008, 0.045, 0.025), rot_x(35))
        dn = ellipsoid(p, (0, 0.045, -0.195), (0.008, 0.03, 0.02), rot_x(-35))
        return smin(smin(d, up, 0.012), dn, 0.012)

    def tail_mask(p, n):
        return np.stack([_sm(-n[:, 1], -0.2, 0.3) * _sm(-(p[:, 1] - 0.065), -0.008, 0.008), np.zeros(len(p))], -1)

    c = np.array([0, 0.06, 0.03])
    bp = Part("body", body, ([-0.12, -0.01, -0.1], [0.12, 0.2, 0.2]), c, 0.2,
              [cap_shape([0, 0, 0.07], [0, 0.005, -0.09], 0.05)], body_mask, faces=9000)
    acc = eyes_on(body, (0, 0.07, 0.1), [(0.7, 0.25, 0.65), (-0.7, 0.25, 0.65)], 0.0065)
    m0, _ = surface_point(body, (0, 0.04, 0.12), (0, -0.05, 1))
    bp.accessories = acc
    t0 = np.array([0, 0.065, -0.07])
    tp = Part("tail", tail, ([-0.06, -0.0, -0.24], [0.06, 0.18, -0.03]), t0, 0.06,
              [cap_shape([0, 0, -0.01], [0, 0.008, -0.1], 0.03), sph_shape([0, 0.045, -0.13], 0.02)], tail_mask, faces=4000)
    joints = [joint("body", "tail", t0, swing=30, twist=15, stiffness=0.6)]
    return {"id": "shark", "parts": [bp, tp], "joints": joints, "fabric": "minky", "height": 0.15}


# ======================================================================== 개구리
def frog():
    c = np.array([0, 0.06, 0])

    def body(p):
        d = ellipsoid(p, c, (0.085, 0.062, 0.075))
        for sx in (1, -1):
            d = smin(d, sphere(p, (0.04 * sx, 0.115, 0.03), 0.03), 0.02)
            d = smin(d, ellipsoid(p, (0.07 * sx, 0.012, 0.055), (0.03, 0.012, 0.03)), 0.01)
            d = smin(d, ellipsoid(p, (0.07 * sx, 0.015, -0.035), (0.035, 0.016, 0.04)), 0.012)
        d = smax(d, -(p[:, 1]), 0.012)
        return seam(d=d, p=p, normal=(0, 1, 0.3), offset=0.06)

    def mask(p, n):
        belly = (1 - _sm(ellipsoid(p, (0, 0.045, 0.05), (0.06, 0.04, 0.045)), -0.003, 0.006)) * _sm(n[:, 2], 0.0, 0.4) * _sm(-n[:, 1], -0.6, 0.0)
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - np.array([0.058 * sx, 0.07, 0.055])), 0.008, 0.014))
        return np.stack([belly, blush * 0.9], -1)

    bp = Part("body", body, (c - [0.12, 0.07, 0.11], c + [0.12, 0.11, 0.11]), c, 0.12, [], mask, faces=9000)
    bp.shapes = [{"type": "convex", "points": (np.array(hull_points(body, c - [0.12, 0.07, 0.11], c + [0.12, 0.11, 0.11], voxel=0.004, count=48)) - c).tolist()}]
    acc = []
    for sx in (1, -1):
        e = np.array([0.04 * sx, 0.115, 0.03])
        pos, nrm = surface_point(body, e, (0.15 * sx, 0.25, 1))
        acc.append((f"eye_{sx}", dome(pos, nrm, 0.012, iris=(0.15, 0.1, 0.05)), "eye"))
    m0, _ = surface_point(body, c, (0, 0.15, 1))
    acc.append(thread_curve(body, [m0 + [-0.03, 0.006, -0.012], m0 + [-0.015, -0.004, -0.002], m0, m0 + [0.015, -0.004, -0.002], m0 + [0.03, 0.006, -0.012]], "smile", samples=24, radius=0.0013))
    bp.accessories = acc
    return {"id": "frog", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.15}


# ======================================================================== 햄스터 (작은 기계)
def hamster():
    c = np.array([0, 0.04, 0])

    def body(p):
        d = ellipsoid(p, c, (0.042, 0.04, 0.045))
        for sx in (1, -1):
            d = smin(d, sphere(p, (0.028 * sx, 0.04, 0.025), 0.022), 0.015)  # 볼 주머니
            ear = ellipsoid(p, (0.026 * sx, 0.077, -0.004), (0.012, 0.012, 0.005))
            d = smin(d, ear, 0.006)
            d = smin(d, sphere(p, (0.015 * sx, 0.015, 0.04), 0.008), 0.004)
        d = smax(d, -(p[:, 1]), 0.008)
        return d

    def mask(p, n):
        belly = (1 - _sm(ellipsoid(p, (0, 0.028, 0.03), (0.034, 0.03, 0.03)), -0.002, 0.004)) * _sm(n[:, 2], -0.2, 0.3)
        cheeks = np.zeros(len(p))
        for sx in (1, -1):
            cheeks = np.maximum(cheeks, 1 - _sm(length(p - np.array([0.034 * sx, 0.04, 0.032])), 0.012, 0.018))
        inner = np.zeros(len(p))
        for sx in (1, -1):
            inner = np.maximum(inner, (1 - _sm(length(p - np.array([0.026 * sx, 0.078, 0.0])), 0.005, 0.008)) * _sm(n[:, 2], 0.3, 0.7))
        return np.stack([np.maximum(belly, cheeks), inner], -1)

    bp = Part("body", body, (c - 0.06, c + 0.06), c, 0.04, [], mask, faces=6000, voxel=0.0007)
    bp.shapes = [sph_shape([0, 0, 0], 0.04)]
    acc = eyes_on(body, (0, 0.05, 0.0), [(0.4, 0.2, 0.9), (-0.4, 0.2, 0.9)], 0.0042)
    nt, nn = surface_point(body, (0, 0.04, 0.0), (0, 0.05, 1))
    acc.append(sdf_blob_mesh("nose", lambda p: sphere(p, nt + nn * 0.001, 0.0028), nt, 0.005, (0.95, 0.55, 0.6), "thread", voxel=0.0003, faces=300))
    bp.accessories = acc
    return {"id": "hamster", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.085}


# ======================================================================== 고래 (작은 기계)
def whale():
    def body(p):
        d = round_cone(p, (0, 0.04, 0.03), (0, 0.035, -0.05), 0.04, 0.02)
        d = smin(d, sphere(p, (0, 0.042, 0.035), 0.042), 0.02)
        for sx in (1, -1):
            fl = ellipsoid(p, (0.025 * sx, 0.04, -0.085), (0.026, 0.006, 0.014), rot_y(-30 * sx))
            d = smin(d, fl, 0.008)
            fin = ellipsoid(p, (0.04 * sx, 0.02, 0.03), (0.016, 0.005, 0.01), rot_z(25 * sx))
            d = smin(d, fin, 0.006)
        d = smax(d, -(p[:, 1]), 0.006)
        return d

    def mask(p, n):
        belly = _sm(-n[:, 1], -0.3, 0.2) * _sm(-(p[:, 1] - 0.035), -0.006, 0.006)
        blush = np.zeros(len(p))
        for sx in (1, -1):
            blush = np.maximum(blush, 1 - _sm(length(p - np.array([0.03 * sx, 0.035, 0.062])), 0.005, 0.009))
        return np.stack([belly, blush * 0.9], -1)

    c = np.array([0, 0.04, 0])
    bp = Part("body", body, ([-0.07, -0.01, -0.12], [0.07, 0.1, 0.09]), c, 0.04, [], mask, faces=6000, voxel=0.0008)
    bp.shapes = [sph_shape([0, 0.002, 0.03], 0.04), cap_shape([0, 0, 0.0], [0, -0.003, -0.06], 0.022)]
    acc = eyes_on(body, (0, 0.045, 0.03), [(0.62, 0.15, 0.77), (-0.62, 0.15, 0.77)], 0.004)
    m0, _ = surface_point(body, (0, 0.03, 0.03), (0, -0.2, 1))
    acc.append(thread_curve(body, [m0 + [-0.012, 0.002, -0.004], m0, m0 + [0.012, 0.002, -0.004]], "smile", radius=0.0009, samples=12))
    bp.accessories = acc
    return {"id": "whale", "parts": [bp], "joints": [], "fabric": "minky", "height": 0.09}


# ======================================================================== 일본식 프라이즈 피규어 상자
def _uv_box_atlas(size, rects):
    """rects: front/back/right/left/top/bottom → (u0, v0, u1, v1) 이미지 좌표(위가 0)."""
    hx, hy, hz = np.asarray(size) / 2
    faces = {
        "front": ((0, 0, 1), [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]),
        "back": ((0, 0, -1), [(hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)]),
        "right": ((1, 0, 0), [(hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz)]),
        "left": ((-1, 0, 0), [(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)]),
        "top": ((0, 1, 0), [(-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz)]),
        "bottom": ((0, -1, 0), [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]),
    }
    V, N, UV, F = [], [], [], []
    for k, (nrm, cs) in faces.items():
        u0, v0, u1, v1 = rects[k]
        b = len(V)
        uvs = [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)]
        for cc, uv in zip(cs, uvs):
            V.append(cc)
            N.append(nrm)
            UV.append(uv)
        F += [[b, b + 1, b + 2], [b, b + 2, b + 3]]
    m = trimesh.Trimesh(np.array(V), np.array(F), vertex_normals=np.array(N), process=False)
    m.visual = trimesh.visual.TextureVisuals(uv=np.array(UV))
    return m


JP_RECTS = {"front": (0.0, 0.0, 0.6, 0.4), "back": (0.0, 0.4, 0.6, 0.8), "top": (0.0, 0.8, 0.6, 1.0),
            "bottom": (0.0, 0.8, 0.6, 1.0), "right": (0.6, 0.0, 0.8, 0.4), "left": (0.8, 0.0, 1.0, 0.4)}


def figure_jp():
    # 실제 프라이즈 피규어 상자 크기(가로 28 × 세로 20 × 두께 15cm)
    size = (0.28, 0.20, 0.15)
    m = _uv_box_atlas(size, JP_RECTS)
    m.apply_translation([0, size[1] / 2, 0])
    p = MeshPart("box", m, [0, size[1] / 2, 0], 0.45, [box_shape([0, 0, 0], np.array(size) / 2)])
    return {"id": "figure_jp", "parts": [p], "joints": [], "material": "printed", "height": size[1]}


MODELS.update({"panda": panda, "shiba": shiba, "shark": shark, "frog": frog, "hamster": hamster,
               "whale": whale, "figure_jp": figure_jp})
