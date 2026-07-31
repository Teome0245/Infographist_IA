"""Prépare un PNG ComfyUI pour sprite top-down Prime Client (échelle normalisée)."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

# Part du canvas occupée par le personnage (uniformise bot vs garde mécha)
FILL_RATIO = 0.78


def _alpha_bbox(img: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = img.split()[-1]
    bbox = alpha.point(lambda p: 255 if p > threshold else 0).getbbox()
    return bbox


def prepare_sprite(
    src: Path,
    dst: Path,
    size: int = 128,
    remove_bg: bool = False,
    fill_ratio: float = FILL_RATIO,
) -> None:
    img = Image.open(src).convert("RGBA")

    if remove_bg:
        try:
            from rembg import remove

            img = remove(img)
        except Exception as e:
            print(f"rembg ignoré ({e})")

    bbox = _alpha_bbox(img)
    if bbox:
        img = img.crop(bbox)

    cw, ch = img.size
    if cw < 1 or ch < 1:
        raise ValueError(f"Image vide après crop: {src}")

    target_side = int(size * fill_ratio)
    scale = target_side / max(cw, ch)
    nw = max(1, int(cw * scale))
    nh = max(1, int(ch * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst)
    print(f"Sprite: {dst} ({size}x{size}, fill={fill_ratio:.0%})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--size", type=int, default=128)
    parser.add_argument("--fill-ratio", type=float, default=FILL_RATIO)
    parser.add_argument("--remove-bg", action="store_true")
    args = parser.parse_args()
    prepare_sprite(
        Path(args.input),
        Path(args.output),
        args.size,
        args.remove_bg,
        args.fill_ratio,
    )


if __name__ == "__main__":
    main()
