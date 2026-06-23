"""Tesseract OCR service for SPM academic document processing.

Extracts positioned text fragments from uploaded certificate images and
groups them into rows compatible with the Flutter ``OcrPostProcessor`` /
``AcademicResultParser`` pipeline.

Configuration (matches approved POC):
  - PSM 4 (single column, variable-size text)
  - Grayscale preprocessing
  - Downscale to max 2000 px width
  - Confidence filtering (drop fragments with conf < 30)
"""

from __future__ import annotations

import io
import logging
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import pytesseract
    from PIL import Image, ImageOps, UnidentifiedImageError
except ImportError as exc:  # pragma: no cover - import guard
    raise ImportError(
        "OCR dependencies missing. Install with: pip install pytesseract Pillow"
    ) from exc

logger = logging.getLogger(__name__)

THRESHOLD_FACTOR = 0.6
MIN_CONFIDENCE = 30
MAX_WIDTH = 2000
TESSERACT_CONFIG = "--psm 4"

_windows_tesseract = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
if _windows_tesseract.exists():
    pytesseract.pytesseract.tesseract_cmd = str(_windows_tesseract)
elif shutil.which("tesseract"):
    pytesseract.pytesseract.tesseract_cmd = shutil.which("tesseract")  # type: ignore[assignment]


@dataclass
class Fragment:
    text: str
    top: float
    bottom: float
    left: float
    right: float

    @property
    def center_y(self) -> float:
        return (self.top + self.bottom) / 2.0

    @property
    def height(self) -> float:
        return self.bottom - self.top


@dataclass
class Row:
    fragments: list[Fragment]


class OcrService:
    """Stateless Tesseract wrapper used by ``POST /ocr``."""

    def is_available(self) -> bool:
        try:
            pytesseract.get_tesseract_version()
            return True
        except Exception as exc:  # noqa: BLE001
            logger.warning("Tesseract not available: %s", exc)
            return False

    def process_image_bytes(self, data: bytes) -> dict[str, Any]:
        """Run OCR on raw image bytes and return row-grouped fragments."""
        if not data:
            raise ValueError("Empty image payload.")

        try:
            image = Image.open(io.BytesIO(data))
        except UnidentifiedImageError as exc:
            raise ValueError("Uploaded file is not a supported image.") from exc

        processed = self._preprocess(image)
        fragments = self._extract_fragments(processed)
        rows = self._group_into_rows(fragments)

        return {
            "rows": [
                {
                    "fragments": [
                        {
                            "text": fragment.text,
                            "top": fragment.top,
                            "bottom": fragment.bottom,
                            "left": fragment.left,
                            "right": fragment.right,
                        }
                        for fragment in row.fragments
                    ]
                }
                for row in rows
            ]
        }

    @staticmethod
    def _preprocess(image: Image.Image) -> Image.Image:
        gray = ImageOps.grayscale(image.convert("RGB"))
        if gray.width > MAX_WIDTH:
            ratio = MAX_WIDTH / gray.width
            gray = gray.resize(
                (MAX_WIDTH, int(gray.height * ratio)),
                Image.Resampling.LANCZOS,
            )
        return gray

    @staticmethod
    def _extract_fragments(image: Image.Image) -> list[Fragment]:
        data = pytesseract.image_to_data(
            image,
            lang="eng",
            config=TESSERACT_CONFIG,
            output_type=pytesseract.Output.DICT,
        )
        fragments: list[Fragment] = []
        count = len(data["text"])
        for i in range(count):
            text = (data["text"][i] or "").strip()
            if not text:
                continue
            try:
                conf = float(data["conf"][i])
            except ValueError:
                conf = -1.0
            if conf >= 0 and conf < MIN_CONFIDENCE:
                continue

            left = float(data["left"][i])
            top = float(data["top"][i])
            width = float(data["width"][i])
            height = float(data["height"][i])
            fragments.append(
                Fragment(
                    text=text,
                    top=top,
                    bottom=top + height,
                    left=left,
                    right=left + width,
                )
            )
        return fragments

    @staticmethod
    def _group_into_rows(fragments: list[Fragment]) -> list[Row]:
        if not fragments:
            return []

        sorted_frags = sorted(fragments, key=lambda fragment: fragment.center_y)
        avg_height = sum(fragment.height for fragment in sorted_frags) / len(sorted_frags)
        threshold = avg_height * THRESHOLD_FACTOR

        groups: list[list[Fragment]] = []
        center_sums: list[float] = []
        counts: list[int] = []

        for fragment in sorted_frags:
            best_group = -1
            best_distance = float("inf")
            for index, _group in enumerate(groups):
                row_center = center_sums[index] / counts[index]
                distance = abs(fragment.center_y - row_center)
                if distance <= threshold and distance < best_distance:
                    best_distance = distance
                    best_group = index

            if best_group == -1:
                groups.append([fragment])
                center_sums.append(fragment.center_y)
                counts.append(1)
            else:
                groups[best_group].append(fragment)
                center_sums[best_group] += fragment.center_y
                counts[best_group] += 1

        order = sorted(range(len(groups)), key=lambda index: center_sums[index] / counts[index])
        rows: list[Row] = []
        for index in order:
            row_fragments = sorted(groups[index], key=lambda fragment: fragment.left)
            rows.append(Row(row_fragments))
        return rows


ocr_service = OcrService()
