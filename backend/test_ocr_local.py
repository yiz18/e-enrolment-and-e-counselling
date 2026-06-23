"""Local test for POST /ocr (Tesseract web OCR fallback).

Usage
-----
# Terminal 1 — start the server from backend/
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2 — run this script from backend/
    python test_ocr_local.py
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE_URL = "http://localhost:8000"
SAMPLE_IMAGE = Path(__file__).resolve().parent / "poc" / "spm_sample_yyz.jpg"

PASS = "\033[92mPASS\033[0m"
FAIL = "\033[91mFAIL\033[0m"
DIVIDER = "=" * 60


def section(title: str) -> None:
    print(f"\n{DIVIDER}\n  {title}\n{DIVIDER}")


def test_direct_ocr_service() -> bool:
    section("STEP 1 — Direct OcrService.process_image_bytes()")

    if not SAMPLE_IMAGE.exists():
        print(f"  {FAIL}  Sample image not found: {SAMPLE_IMAGE}")
        return False

    try:
        from app.services.ocr_service import ocr_service

        if not ocr_service.is_available():
            print(f"  {FAIL}  Tesseract is not installed on this machine.")
            print("  Install with: winget install UB-Mannheim.TesseractOCR")
            return False

        payload = ocr_service.process_image_bytes(SAMPLE_IMAGE.read_bytes())
        rows = payload.get("rows", [])
        print(f"  Tesseract available : {PASS}")
        print(f"  Row count           : {len(rows)}")
        print(f"  Fragment count      : {sum(len(r['fragments']) for r in rows)}")

        ic_found = any(
            "011018-07-0829" in " ".join(f["text"] for f in row["fragments"])
            for row in rows
        )
        print(f"  IC detected         : {'YES' if ic_found else 'NO'}")
        if not ic_found:
            print(f"  {FAIL}  Expected IC 011018-07-0829 in OCR output")
            return False

        print(f"\n  {PASS}")
        return True
    except Exception as exc:  # noqa: BLE001
        print(f"  {FAIL}  {exc}")
        return False


def _multipart_post_ocr(image_path: Path) -> tuple[int, dict | str]:
    boundary = "----WebOcrTestBoundary7MA4YWxkTrZu0gW"
    image_bytes = image_path.read_bytes()
    filename = image_path.name

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        "Content-Type: image/jpeg\r\n\r\n"
    ).encode("utf-8") + image_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

    request = urllib.request.Request(
        f"{BASE_URL}/ocr",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, raw.decode("utf-8", errors="replace")


def test_http_ocr() -> bool:
    section("STEP 2 — HTTP POST /ocr")

    if not SAMPLE_IMAGE.exists():
        print(f"  {FAIL}  Sample image not found: {SAMPLE_IMAGE}")
        return False

    try:
        status, body = _multipart_post_ocr(SAMPLE_IMAGE)
    except urllib.error.URLError as exc:
        print(f"  {FAIL}  Server not reachable — {exc.reason}")
        print("  Start the server first: uvicorn app.main:app --reload --port 8000")
        return False

    if status != 200:
        print(f"  {FAIL}  HTTP {status}")
        print(f"  Body: {body}")
        return False

    if not isinstance(body, dict) or "rows" not in body:
        print(f"  {FAIL}  Response missing 'rows'")
        return False

    rows = body["rows"]
    ic_found = any(
        "011018-07-0829" in " ".join(f["text"] for f in row["fragments"])
        for row in rows
    )

    print(f"  POST /ocr          : {PASS}  HTTP {status}")
    print(f"  Row count          : {len(rows)}")
    print(f"  IC detected        : {'YES' if ic_found else 'NO'}")
    return ic_found


def main() -> None:
    print("\nOCR API — Local Test")
    print(f"Sample image: {SAMPLE_IMAGE}\n")

    results = {
        "direct": test_direct_ocr_service(),
        "http": test_http_ocr(),
    }

    section("SUMMARY")
    labels = {
        "direct": "Direct OcrService",
        "http": "HTTP POST /ocr",
    }
    all_pass = True
    for key, passed in results.items():
        icon = PASS if passed else FAIL
        print(f"  {icon}  {labels[key]}")
        if not passed:
            all_pass = False

    print()
    if all_pass:
        print("  All OCR checks passed.")
    else:
        print("  One or more OCR checks failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
