"""Convertit mesh OBJ (xatlas) + texture PNG en GLB valide pour Godot."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image


def obj_with_uv_to_glb(obj_path: Path, texture_path: Path, out_path: Path) -> trimesh.Trimesh:
    verts: list[list[float]] = []
    uvs: list[list[float]] = []
    faces_v: list[list[int]] = []
    faces_vt: list[list[int]] = []

    with obj_path.open(encoding="utf-8") as f:
        for line in f:
            p = line.strip().split()
            if not p:
                continue
            if p[0] == "v":
                verts.append([float(x) for x in p[1:4]])
            elif p[0] == "vt":
                uvs.append([float(x) for x in p[1:3]])
            elif p[0] == "f":
                fv, fvt = [], []
                for c in p[1:]:
                    bits = c.split("/")
                    fv.append(int(bits[0]) - 1)
                    fvt.append(int(bits[1]) - 1 if len(bits) > 1 and bits[1] else 0)
                faces_v.append(fv)
                faces_vt.append(fvt)

    verts_np = np.array(verts, dtype=np.float64)
    uvs_np = np.array(uvs, dtype=np.float64)

    new_verts: list[np.ndarray] = []
    new_uvs: list[np.ndarray] = []
    new_faces: list[list[int]] = []
    for fv, fvt in zip(faces_v, faces_vt):
        tri = []
        for vi, ti in zip(fv, fvt):
            new_verts.append(verts_np[vi])
            new_uvs.append(uvs_np[ti])
            tri.append(len(new_verts) - 1)
        new_faces.append(tri)

    img = Image.open(texture_path).convert("RGBA")
    material = trimesh.visual.material.PBRMaterial(
        baseColorTexture=img,
        metallicFactor=0.0,
        roughnessFactor=1.0,
    )
    mesh = trimesh.Trimesh(
        vertices=np.array(new_verts, dtype=np.float64),
        faces=np.array(new_faces, dtype=np.int64),
        process=False,
    )
    mesh.visual = trimesh.visual.TextureVisuals(
        uv=np.array(new_uvs, dtype=np.float64),
        material=material,
    )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    mesh.export(str(out_path))
    return mesh


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--obj", required=True)
    parser.add_argument("--texture", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    mesh = obj_with_uv_to_glb(Path(args.obj), Path(args.texture), Path(args.output))
    print(f"GLB exporté: {args.output}")
    print(f"Faces: {len(mesh.faces)} | Sommets: {len(mesh.vertices)}")


if __name__ == "__main__":
    main()
