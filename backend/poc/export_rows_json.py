"""Export Tesseract rows to JSON for Dart AcademicResultParser validation."""

from __future__ import annotations

import json
from pathlib import Path

import tesseract_spm_poc as poc
from PIL import Image

SAMPLE = poc.SAMPLE_COPY
OUT = Path(__file__).resolve().parent / "tesseract_rows_output.json"


def main() -> None:
    image = poc.preprocess(Image.open(SAMPLE))
    fragments = poc.extract_fragments(image)
    rows = poc.group_into_rows(fragments)

    payload = {
        "rows": [
            {
                "fragments": [
                    {
                        "text": f.text,
                        "top": f.top,
                        "bottom": f.bottom,
                        "left": f.left,
                        "right": f.right,
                    }
                    for f in row.fragments
                ]
            }
            for row in rows
        ]
    }
    OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {OUT} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
