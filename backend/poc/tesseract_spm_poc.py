"""Local Tesseract SPM OCR proof-of-concept — NOT production code.

Uses one real sample: SPM_YYZ.jpg (user Downloads folder).
Mirrors Flutter OcrPostProcessor row grouping (threshold factor 0.6)
and key AcademicResultParser heuristics for validation reporting.
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import pytesseract
    from PIL import Image, ImageOps
except ImportError as exc:
    print(f"Missing dependency: {exc}")
    sys.exit(1)

# Windows Tesseract install path (winget UB-Mannheim)
TESSERACT_EXE = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
if TESSERACT_EXE.exists():
    pytesseract.pytesseract.tesseract_cmd = str(TESSERACT_EXE)

SAMPLE_SOURCE = Path(r"C:\Users\User\Downloads\SPM_YYZ.jpg")
POC_DIR = Path(__file__).resolve().parent
SAMPLE_COPY = POC_DIR / "spm_sample_yyz.jpg"

THRESHOLD_FACTOR = 0.6
MIN_CONFIDENCE = 30

IC_PATTERN = re.compile(r"[0-9OIl]{6}[-\s][0-9OIl]{2}[-\s][0-9OIl]{4}", re.I)
CANDIDATE_ID_PATTERN = re.compile(r"^[A-Z][A-Z0-9]{5,11}$")
GRADE_PATTERN = re.compile(r"^([A-E])\s*([+\-]?)\s*(?:\([^)]*\))?$", re.I)
DESCRIPTION_PATTERN = re.compile(r"^\(.*\)$")

NOISE_TOKENS = {
    "kementerian", "lembaga", "examinations", "syndicate", "ministry",
    "calon", "namanya", "tercatat", "bawah", "telah", "menduduki",
    "layak", "dianugerahi", "sijil", "bersekutu", "pertabahan", "mutu",
    "mata", "gred", "grade", "subject", "kepujian", "lulus", "cemerlang",
    "jaya", "jumlah", "pengarah", "peperiksaan", "tahun", "director",
    "sembilan", "lapan", "tujuh", "enam", "lima", "empat", "tiga",
}

# Subset of kSpmSubjects for fuzzy-lite matching in POC
SPM_SUBJECTS = [
    "Bahasa Melayu", "Bahasa Inggeris", "Sejarah", "Pendidikan Islam",
    "Pendidikan Moral", "Matematik", "Matematik Tambahan", "Fizik", "Kimia",
    "Biologi", "Sains", "Mathematics", "Additional Mathematics", "Physics",
    "Chemistry", "Biology", "Science", "Sains Komputer", "Computer Science",
    "Ekonomi", "Perakaunan", "Perdagangan", "Geografi", "Bahasa Cina",
    "Bahasa Tamil", "Pendidikan Seni Visual", "English", "History",
]


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

    @property
    def text(self) -> str:
        return "  ".join(f.text for f in self.fragments)


def preprocess(image: Image.Image) -> Image.Image:
    gray = ImageOps.grayscale(image)
    # Resize very large phone photos for faster/stable OCR
    max_width = 2000
    if gray.width > max_width:
        ratio = max_width / gray.width
        gray = gray.resize((max_width, int(gray.height * ratio)), Image.Resampling.LANCZOS)
    return gray


def extract_fragments(image: Image.Image) -> list[Fragment]:
    data = pytesseract.image_to_data(image, lang="eng", config="--psm 6", output_type=pytesseract.Output.DICT)
    fragments: list[Fragment] = []
    n = len(data["text"])
    for i in range(n):
        text = (data["text"][i] or "").strip()
        if not text:
            continue
        try:
            conf = float(data["conf"][i])
        except ValueError:
            conf = -1
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


def group_into_rows(fragments: list[Fragment]) -> list[Row]:
    if not fragments:
        return []
    sorted_frags = sorted(fragments, key=lambda f: f.center_y)
    avg_height = sum(f.height for f in sorted_frags) / len(sorted_frags)
    threshold = avg_height * THRESHOLD_FACTOR

    groups: list[list[Fragment]] = []
    center_sums: list[float] = []
    counts: list[int] = []

    for fragment in sorted_frags:
        best_group = -1
        best_distance = float("inf")
        for i, _group in enumerate(groups):
            row_center = center_sums[i] / counts[i]
            distance = abs(fragment.center_y - row_center)
            if distance <= threshold and distance < best_distance:
                best_distance = distance
                best_group = i
        if best_group == -1:
            groups.append([fragment])
            center_sums.append(fragment.center_y)
            counts.append(1)
        else:
            groups[best_group].append(fragment)
            center_sums[best_group] += fragment.center_y
            counts[best_group] += 1

    order = sorted(range(len(groups)), key=lambda i: center_sums[i] / counts[i])
    rows: list[Row] = []
    for i in order:
        frags = sorted(groups[i], key=lambda f: f.left)
        rows.append(Row(frags))
    return rows


def contains_noise(text: str) -> bool:
    return any(token in text.lower().split() for token in NOISE_TOKENS)


def levenshtein_ratio(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    la, lb = len(a), len(b)
    dp = list(range(lb + 1))
    for i, ca in enumerate(a, 1):
        prev = dp[0]
        dp[0] = i
        for j, cb in enumerate(b, 1):
            temp = dp[j]
            cost = 0 if ca == cb else 1
            dp[j] = min(dp[j] + 1, dp[j - 1] + 1, prev + cost)
            prev = temp
    dist = dp[lb]
    return 1.0 - dist / max(la, lb)


def match_subject(raw: str) -> str | None:
    best = None
    best_score = 0.0
    norm = raw.strip().upper()
    for subject in SPM_SUBJECTS:
        score = levenshtein_ratio(norm, subject.upper())
        if score > best_score:
            best_score = score
            best = subject
    if best_score >= 0.55:
        return best
    return None


def normalise_ic(raw: str) -> str:
    return (
        raw.upper()
        .replace("O", "0")
        .replace("I", "1")
        .replace("L", "1")
        .replace(" ", "-")
    )


def extract_student_info(rows: list[Row]) -> dict:
    ic_index = -1
    ic_number = ""
    for i, row in enumerate(rows):
        match = IC_PATTERN.search(row.text)
        if match:
            ic_index = i
            ic_number = normalise_ic(match.group(0))
            break

    name = ""
    if ic_index >= 0:
        start = max(0, ic_index - 5)
        best_score = float("-inf")
        best_name = ""
        for i in range(start, ic_index):
            text = rows[i].text.strip()
            score = 0.0
            if not text or contains_noise(text):
                continue
            if re.search(r"[0-9]", text):
                score -= 5
            if re.match(r"^[A-Za-z\s@/'.-]+$", text):
                score += 3
            if text == text.upper():
                score += 1
            if 5 <= len(text) <= 50:
                score += 1
            words = len(text.split())
            if words >= 2:
                score += 1
            if words >= 3:
                score += 0.5
            if score > best_score:
                best_score = score
                best_name = text
        name = best_name

    candidate_id = ""
    if ic_index >= 0:
        limit = min(ic_index + 3, len(rows))
        for i in range(ic_index + 1, limit):
            text = rows[i].text.strip()
            if CANDIDATE_ID_PATTERN.match(text):
                candidate_id = text
                break
            for frag in rows[i].fragments:
                t = frag.text.strip()
                if CANDIDATE_ID_PATTERN.match(t):
                    candidate_id = t
                    break

    return {"name": name, "ic": ic_number, "candidateId": candidate_id, "icRowIndex": ic_index}


def extract_results(rows: list[Row]) -> list[dict]:
    all_fragments = [frag for row in rows for frag in row.fragments]
    results: list[dict] = []
    pending_subject: str | None = None

    for frag in all_fragments:
        raw = frag.text.strip()
        if not raw:
            continue
        if DESCRIPTION_PATTERN.match(raw):
            continue
        grade_match = GRADE_PATTERN.match(raw.upper())
        if grade_match:
            letter = grade_match.group(1).upper()
            modifier = grade_match.group(2) or ""
            grade = (letter + modifier).replace(" ", "")
            if pending_subject:
                results.append({"subject": pending_subject, "grade": grade})
                pending_subject = None
            continue
        if contains_noise(raw):
            continue
        subject = match_subject(raw)
        if subject:
            pending_subject = subject

    seen = set()
    deduped = []
    for item in results:
        if item["subject"] in seen:
            continue
        seen.add(item["subject"])
        deduped.append(item)
    return deduped


def main() -> None:
    if not SAMPLE_SOURCE.exists():
        print(f"Sample not found: {SAMPLE_SOURCE}")
        sys.exit(1)

    shutil.copy2(SAMPLE_SOURCE, SAMPLE_COPY)
    print(f"Sample: {SAMPLE_SOURCE}")
    print(f"Copied to: {SAMPLE_COPY}")
    print(f"Tesseract: {pytesseract.pytesseract.tesseract_cmd}")

    image = preprocess(Image.open(SAMPLE_COPY))
    print(f"Image size after preprocess: {image.size}")

    raw_text = pytesseract.image_to_string(image, lang="eng", config="--psm 6")
    fragments = extract_fragments(image)
    rows = group_into_rows(fragments)
    student = extract_student_info(rows)
    results = extract_results(rows)

    print("\n=== 1. RAW OCR OUTPUT (Tesseract --psm 6, eng) ===")
    print(raw_text[:4000])
    if len(raw_text) > 4000:
        print(f"... [{len(raw_text) - 4000} more chars]")

    print("\n=== 2. EXTRACTED ROWS (OcrPostProcessor-style grouping) ===")
    for i, row in enumerate(rows):
        print(f"Row {i:03d}: {row.text}")

    print("\n=== 3. PARSER COMPATIBILITY CHECK (heuristic simulation) ===")
    print(json.dumps({"studentInfo": student, "results": results}, indent=2, ensure_ascii=False))

    print("\n=== SUMMARY ===")
    print(f"Fragment count: {len(fragments)}")
    print(f"Row count: {len(rows)}")
    print(f"IC found: {'YES' if student['ic'] else 'NO'} -> {student['ic']}")
    print(f"Name found: {'YES' if student['name'] else 'NO'} -> {student['name']}")
    print(f"Candidate ID found: {'YES' if student['candidateId'] else 'NO'} -> {student['candidateId']}")
    print(f"Subject-grade pairs: {len(results)}")
    for r in results:
        print(f"  - {r['subject']}: {r['grade']}")


if __name__ == "__main__":
    main()
