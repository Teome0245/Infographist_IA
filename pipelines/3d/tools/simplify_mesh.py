"""Simplifie un mesh pour cible Godot (~8k tris)."""

from __future__ import annotations

import argparse
from pathlib import Path

import trimesh


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target-tris", type=int, default=8000)
    args = parser.parse_args()

    mesh = trimesh.load(args.input, force="mesh")
    if isinstance(mesh, trimesh.Scene):
        mesh = trimesh.util.concatenate(tuple(mesh.geometry.values()))

    n_before = len(mesh.faces)
    print(f"Faces avant: {n_before}")

    if n_before > args.target_tris:
        try:
            import fast_simplification

            verts, faces = fast_simplification.simplify(
                mesh.vertices, mesh.faces, target_count=args.target_tris
            )
            mesh = trimesh.Trimesh(
                vertices=verts,
                faces=faces,
                process=False,
                visual=mesh.visual,
            )
        except Exception as e:
            print(f"Simplification échouée ({e}), export brut.")
    n_after = len(mesh.faces)
    print(f"Faces après: {n_after}")

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    mesh.export(str(out))
    print(f"Export: {out}")


if __name__ == "__main__":
    main()
