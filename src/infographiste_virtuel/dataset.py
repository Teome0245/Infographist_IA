"""Scan et validation du dossier dataset/."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif"}


@dataclass
class DatasetImage:
    path: Path
    relative_path: Path
    has_caption: bool


@dataclass
class DatasetReport:
    root: Path
    images: list[DatasetImage]

    @property
    def count(self) -> int:
        return len(self.images)

    @property
    def caption_count(self) -> int:
        return sum(1 for img in self.images if img.has_caption)


def scan_dataset(dataset_dir: Path) -> DatasetReport:
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Dossier dataset introuvable: {dataset_dir}")

    images: list[DatasetImage] = []
    for path in sorted(dataset_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        caption = path.with_suffix(".txt")
        images.append(
            DatasetImage(
                path=path,
                relative_path=path.relative_to(dataset_dir),
                has_caption=caption.exists(),
            )
        )

    return DatasetReport(root=dataset_dir, images=images)


def print_dataset_report(report: DatasetReport) -> None:
    print(f"Dataset: {report.root}")
    print(f"  Images: {report.count}")
    print(f"  Captions: {report.caption_count}/{report.count}")
    for img in report.images[:10]:
        cap = "caption" if img.has_caption else "sans caption"
        print(f"  - {img.relative_path} ({cap})")
    if report.count > 10:
        print(f"  ... (+{report.count - 10} autres)")
