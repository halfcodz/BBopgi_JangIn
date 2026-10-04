"""
SDF(부호 거리 함수) 기반 인형 모델링 도구.
- 기본 도형(구, 타원체, 캡슐, 테이퍼 캡슐, 원환, 둥근 상자)과 부드러운 합집합(smin)
- 마칭 큐브로 메시화 → 스무딩 → 감축 → SDF 그라디언트로 매끈한 노멀 재계산
- 표면 위 곡선(자수 실), 플라스틱 눈 등 부속 메시 생성
모든 단위는 미터, Y가 위, +Z가 정면.
"""
import numpy as np
import trimesh
from skimage import measure
import fast_simplification


# ---------------------------------------------------------------- primitives
def length(v):
    return np.sqrt(np.sum(v * v, axis=-1))


def sphere(p, c, r):
    return length(p - np.asarray(c)) - r


def ellipsoid(p, c, radii, rot=None):
    q = p - np.asarray(c)
    if rot is not None:
        q = q @ np.asarray(rot)  # rot: 3x3 (월드→로컬은 전치)
    r = np.asarray(radii, dtype=float)
    k0 = length(q / r)
    k1 = length(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def capsule(p, a, b, r):
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    pa = p - a
    ba = b - a
    h = np.clip(np.sum(pa * ba, axis=-1) / np.dot(ba, ba), 0.0, 1.0)
    return length(pa - h[:, None] * ba) - r


def round_cone(p, a, b, r1, r2):
    """양 끝 반지름이 다른 캡슐 (Inigo Quilez sdRoundCone)."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    ba = b - a
    l2 = np.dot(ba, ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = np.sum(pa * ba, axis=-1)
    z = y - l2
    xv = pa * l2 - y[:, None] * ba
    x2 = np.sum(xv * xv, axis=-1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    out = np.empty(len(p))
    m1 = np.sign(z) * a2 * z2 > k
    m2 = (~m1) & (np.sign(y) * a2 * y2 < k)
    m3 = ~(m1 | m2)
    out[m1] = np.sqrt(x2[m1] + z2[m1]) * il2 - r2
    out[m2] = np.sqrt(x2[m2] + y2[m2]) * il2 - r1
    out[m3] = (np.sqrt(x2[m3] * a2 * il2) + y[m3] * rr) * il2 - r1
    return out


def torus(p, c, R, r, axis="z"):
    q = p - np.asarray(c)
    if axis == "z":
        xy = np.stack([q[:, 0], q[:, 1]], -1)
        h = q[:, 2]
    elif axis == "x":
        xy = np.stack([q[:, 1], q[:, 2]], -1)
        h = q[:, 0]
    else:
        xy = np.stack([q[:, 0], q[:, 2]], -1)
        h = q[:, 1]
    d = length(xy) - R
    return np.sqrt(d * d + h * h) - r


def round_box(p, c, half, r, rot=None):
    q = p - np.asarray(c)
    if rot is not None:
        q = q @ np.asarray(rot)
    q = np.abs(q) - (np.asarray(half) - r)
    outside = length(np.maximum(q, 0.0))
    inside = np.minimum(np.max(q, axis=-1), 0.0)
    return outside + inside - r


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def union(*ds):
    out = ds[0]
    for d in ds[1:]:
        out = np.minimum(out, d)
    return out


def sunion(k, *ds):
    out = ds[0]
    for d in ds[1:]:
        out = smin(out, d, k)
    return out


def seam(p, d, normal, offset, depth=0.0011, width=0.0014, mask=None):
    """봉제선: 평면(normal·p = offset) 근처 표면을 살짝 눌러 홈을 만든다."""
    n = np.asarray(normal, float)
    n = n / np.linalg.norm(n)
    s = p @ n - offset
    g = depth * np.exp(-(s / width) ** 2)
    # 표면 근처에서만 효과
    g *= np.exp(-(d / 0.004) ** 2)
    if mask is not None:
        g *= mask
    return d + g


def rot_y(deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


# ---------------------------------------------------------------- meshing
def gradient(f, p, eps=2.5e-4):
    ex = np.array([eps, 0, 0])
    ey = np.array([0, eps, 0])
    ez = np.array([0, 0, eps])
    g = np.stack([
        f(p + ex) - f(p - ex),
        f(p + ey) - f(p - ey),
        f(p + ez) - f(p - ez),
    ], -1)
    n = length(g)[:, None]
    return g / np.maximum(n, 1e-12)


def project_to_surface(f, p, iters=8):
    p = np.array(p, float).reshape(-1, 3)
    for _ in range(iters):
        d = f(p)
        n = gradient(f, p)
        p = p - d[:, None] * n
    return p


def mesh_sdf(f, bmin, bmax, voxel=0.0016, target_faces=9000, smooth_iters=6):
    bmin = np.asarray(bmin, float)
    bmax = np.asarray(bmax, float)
    dims = np.ceil((bmax - bmin) / voxel).astype(int) + 1
    xs = [bmin[i] + np.arange(dims[i]) * voxel for i in range(3)]
    gx, gy, gz = np.meshgrid(*xs, indexing="ij")
    pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], -1)
    vals = np.empty(len(pts))
    chunk = 400000
    for i in range(0, len(pts), chunk):
        vals[i:i + chunk] = f(pts[i:i + chunk])
    vol = vals.reshape(dims)
    verts, faces, _, _ = measure.marching_cubes(vol, level=0.0, spacing=(voxel, voxel, voxel))
    verts += bmin
    mesh = trimesh.Trimesh(verts, faces, process=True)
    # 면 방향을 바깥쪽으로 통일 (부피가 음수면 뒤집힌 것)
    if mesh.volume < 0:
        mesh.invert()
    trimesh.smoothing.filter_taubin(mesh, lamb=0.5, nu=-0.53, iterations=smooth_iters)
    if target_faces and len(mesh.faces) > target_faces:
        v, fcs = fast_simplification.simplify(
            np.asarray(mesh.vertices, np.float32), np.asarray(mesh.faces, np.int32),
            target_reduction=1.0 - target_faces / len(mesh.faces))
        mesh = trimesh.Trimesh(v, fcs, process=True)
    # 표면에 다시 붙이고 SDF 그라디언트로 노멀 계산
    v = project_to_surface(f, np.asarray(mesh.vertices), iters=2)
    mesh = trimesh.Trimesh(v, mesh.faces, process=False)
    if mesh.volume < 0:
        mesh.invert()
    normals = gradient(f, v)
    return mesh, normals


def finalize(mesh, normals, colors):
    """trimesh 메시에 노멀·버텍스 컬러를 고정."""
    cols = np.clip(np.asarray(colors) * 255.0, 0, 255).astype(np.uint8)
    if cols.shape[1] == 3:
        cols = np.concatenate([cols, np.full((len(cols), 1), 255, np.uint8)], 1)
    m = trimesh.Trimesh(mesh.vertices, mesh.faces, vertex_normals=normals,
                        vertex_colors=cols, process=False)
    return m


# ---------------------------------------------------------------- accessories
def tube_along(points, radius, sides=8, cap=True):
    """폴리라인을 따라가는 튜브 메시(자수 실, 고리 등)."""
    pts = np.asarray(points, float)
    n = len(pts)
    tangents = np.gradient(pts, axis=0)
    tangents /= np.linalg.norm(tangents, axis=1, keepdims=True)
    ref = np.array([0, 1, 0.0])
    if abs(np.dot(ref, tangents[0])) > 0.9:
        ref = np.array([1, 0, 0.0])
    verts = []
    normals = []
    u = np.cross(tangents[0], ref)
    u /= np.linalg.norm(u)
    for i in range(n):
        t = tangents[i]
        u = u - np.dot(u, t) * t
        u /= np.linalg.norm(u)
        w = np.cross(t, u)
        for k in range(sides):
            a = 2 * np.pi * k / sides
            dirv = np.cos(a) * u + np.sin(a) * w
            verts.append(pts[i] + radius * dirv)
            normals.append(dirv)
    faces = []
    for i in range(n - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + k
            d = (i + 1) * sides + (k + 1) % sides
            faces.append([a, c, b])
            faces.append([b, c, d])
    verts = np.array(verts)
    normals = np.array(normals)
    if cap:
        for idx, sign in ((0, -1), (n - 1, 1)):
            ci = len(verts)
            verts = np.vstack([verts, pts[idx] + tangents[idx] * radius * 0.6 * sign])
            normals = np.vstack([normals, tangents[idx] * sign])
            base = idx * sides
            for k in range(sides):
                a = base + k
                b = base + (k + 1) % sides
                faces.append([a, b, ci] if sign > 0 else [b, a, ci])
    return trimesh.Trimesh(verts, np.array(faces), vertex_normals=normals, process=False)


def dome(center, normal, radius, depth_ratio=0.45, subdiv=3, color=(0.02, 0.02, 0.025), iris=None):
    """플라스틱 안전눈: 표면에 박힌 반구."""
    s = trimesh.creation.icosphere(subdivisions=subdiv, radius=radius)
    n = np.asarray(normal, float)
    n /= np.linalg.norm(n)
    v = np.asarray(s.vertices)
    vn = v / radius
    # 노멀 방향 쪽을 앞(정면)으로
    front = vn @ n
    cols = np.tile(np.array(color, float), (len(v), 1))
    if iris is not None:
        ring = (front > 0.55) & (front < 0.82)
        cols[ring] = iris
    c = np.asarray(center) - n * radius * (1.0 - depth_ratio * 2.0) * 0.5
    m = trimesh.Trimesh(v + c, s.faces, vertex_normals=vn, process=False)
    return finalize(m, vn, cols)


def surface_curve(f, ctrl, samples=24):
    """제어점(대략 표면 근처)을 Catmull-Rom 으로 잇고 표면에 투영."""
    ctrl = np.asarray(ctrl, float)
    pts = []
    m = len(ctrl)
    for i in range(m - 1):
        p0 = ctrl[max(i - 1, 0)]
        p1 = ctrl[i]
        p2 = ctrl[i + 1]
        p3 = ctrl[min(i + 2, m - 1)]
        for t in np.linspace(0, 1, samples // (m - 1), endpoint=(i == m - 2)):
            t2, t3 = t * t, t * t * t
            pts.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    pts = project_to_surface(f, np.array(pts), iters=10)
    return pts


def surface_point(f, origin, direction):
    """origin 에서 direction 으로 나아가며 표면(f=0)을 찾는다."""
    o = np.asarray(origin, float)
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    t = 0.0
    for _ in range(200):
        p = o + d * t
        v = f(p[None])[0]
        if v > 0:
            break
        t += max(-v, 0.0005)
    # 이분법으로 정밀화
    lo, hi = max(t - 0.01, 0), t
    for _ in range(30):
        mid = (lo + hi) / 2
        if f((o + d * mid)[None])[0] > 0:
            hi = mid
        else:
            lo = mid
    p = o + d * hi
    n = gradient(f, p[None])[0]
    return p, n
