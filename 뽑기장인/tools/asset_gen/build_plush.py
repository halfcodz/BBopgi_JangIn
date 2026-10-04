"""
인형 에셋 빌드: python build_plush.py [모델id ...]
결과: assets/prizes/<id>.glb (부위별 메시 노드) + assets/prizes/<id>.json (래그돌 물리 정의)
"""
import json
import os
import sys
import time

import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(__file__))
from sdf import gradient  # noqa: E402
import plush_models  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "prizes")


def bake_ao(f, p, n, steps=(0.005, 0.011, 0.02, 0.032), strength=1.15):
    """SDF 기반 앰비언트 오클루전: 노멀 방향으로 나가며 주변 형상과의 거리를 비교."""
    base = f(p)
    occ = np.zeros(len(p))
    wsum = 0.0
    w = 1.0
    for h in steps:
        d = f(p + n * h) - base
        occ += w * np.clip((h - d) / h, 0, 1)
        wsum += w
        w *= 0.7
    occ /= wsum
    # SDF 근사 오차(타원체·smin)로 생기는 약한 값은 무시
    occ = np.clip((occ - 0.12) / 0.88, 0, 1)
    return np.clip(1.0 - strength * occ, 0.4, 1.0)


def build(model_id):
    t0 = time.time()
    spec = plush_models.MODELS[model_id]()
    parts = spec["parts"]


    scene = trimesh.Scene()
    out_parts = []
    tri_total = 0
    for part in parts:
        if isinstance(part, plush_models.MeshPart):
            scene.add_geometry(part.mesh, node_name=part.name, geom_name=part.name)
            tri_total += len(part.mesh.faces)
            for (aname, amesh, kind) in part.accessories:
                nm = f"{part.name}__{aname}__{kind}"
                scene.add_geometry(amesh, node_name=nm, geom_name=nm)
            out_parts.append({"name": part.name, "origin": part.origin.tolist(), "mass": part.mass, "shapes": part.shapes})
            continue
        mesh, normals = plush_models.mesh_sdf(part.sdf, part.bounds[0], part.bounds[1],
                                              voxel=part.voxel, target_faces=part.faces)
        v = np.asarray(mesh.vertices)
        if part.mask is not None:
            m = part.mask(v, normals)
        else:
            m = np.zeros((len(v), 2))
        # 부위 자체의 굴곡(귀 안쪽, 주둥이 경계 등)만 굽는다.
        # 부위끼리 맞닿는 그늘은 관절이 움직이므로 실시간 SSAO 에 맡긴다.
        ao = bake_ao(part.sdf, v, normals)
        cols = np.concatenate([m, ao[:, None]], 1)
        fm = plush_models.finalize(mesh, normals, cols)
        tri_total += len(fm.faces)
        scene.add_geometry(fm, node_name=part.name, geom_name=part.name)
        for (aname, amesh, kind) in part.accessories:
            nm = f"{part.name}__{aname}__{kind}"
            scene.add_geometry(amesh, node_name=nm, geom_name=nm)
            tri_total += len(amesh.faces)
        out_parts.append({
            "name": part.name, "origin": part.origin.tolist(), "mass": part.mass,
            "shapes": part.shapes,
        })
    os.makedirs(OUT, exist_ok=True)
    glb = os.path.join(OUT, f"{model_id}.glb")
    scene.export(glb)
    meta = {"id": spec["id"], "fabric": spec.get("fabric", "minky"), "height": spec.get("height", 0.3),
            "parts": out_parts, "joints": spec["joints"]}
    for k in ("rigid", "material"):
        if k in spec:
            meta[k] = spec[k]
    with open(os.path.join(OUT, f"{model_id}.json"), "w", encoding="utf-8") as fp:
        json.dump(meta, fp, ensure_ascii=False, indent=1)
    print(f"{model_id}: {tri_total} tris, {len(parts)} parts, {time.time() - t0:.1f}s")


if __name__ == "__main__":
    ids = sys.argv[1:] or list(plush_models.MODELS.keys())
    for i in ids:
        build(i)
