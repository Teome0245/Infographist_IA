"""Tests classification styles inspiration."""

from __future__ import annotations

from pathlib import Path

import pytest

from infographiste_virtuel.style_classifier import classify_image, load_art_styles, scan_and_classify


@pytest.fixture()
def styles_doc(tmp_path: Path) -> Path:
    path = tmp_path / "art_styles.json"
    path.write_text(
        """
{
  "version": 1,
  "default_style": "unclassified",
  "styles": {
    "tatooine_desert": {
      "folder_hints": ["tatooine", "desert"],
      "keywords": ["sand", "dune"]
    },
    "cantina_interior": {
      "folder_hints": ["cantina"],
      "keywords": ["tavern", "bar"]
    }
  }
}
""",
        encoding="utf-8",
    )
    return path


def test_classify_by_folder(styles_doc: Path, tmp_path: Path) -> None:
    doc = load_art_styles(styles_doc)
    img = tmp_path / "styles/tatooine_desert/sunset.png"
    img.parent.mkdir(parents=True)
    img.write_bytes(b"x")
    style_id, conf, _ = classify_image(
        relative_path=Path("styles/tatooine_desert/sunset.png"),
        image_path=img,
        styles_doc=doc,
    )
    assert style_id == "tatooine_desert"
    assert conf == 1.0


def test_classify_by_keyword(styles_doc: Path, tmp_path: Path) -> None:
    doc = load_art_styles(styles_doc)
    img = tmp_path / "inbox/mos_eisley_cantina_bar.jpg"
    img.parent.mkdir(parents=True)
    img.write_bytes(b"x")
    style_id, conf, reasons = classify_image(
        relative_path=Path("inbox/mos_eisley_cantina_bar.jpg"),
        image_path=img,
        styles_doc=doc,
    )
    assert style_id == "cantina_interior"
    assert conf >= 0.7
    assert reasons


def test_scan_and_classify(styles_doc: Path, tmp_path: Path) -> None:
    (tmp_path / "tatooine/dune_sand_01.png").parent.mkdir(parents=True)
    (tmp_path / "tatooine/dune_sand_01.png").write_bytes(b"x")
    (tmp_path / "misc").mkdir()
    (tmp_path / "misc/random.png").write_bytes(b"x")
    report = scan_and_classify(tmp_path, styles_doc)
    assert report.count == 2
    buckets = report.buckets()
    assert buckets["tatooine_desert"]
    assert buckets["unclassified"]
