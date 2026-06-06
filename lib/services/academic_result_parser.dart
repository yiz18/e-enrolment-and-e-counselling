import 'dart:math';

import '../models/academic_result_entry.dart';
import '../models/parsed_academic_result.dart';
import '../models/student_info.dart';
import 'ocr_post_processor.dart';
import 'subject_corrector.dart';
import 'subject_normalizer.dart';

// ── Internal fragment classification ─────────────────────────────────────────

enum _FragmentType { subject, grade, description, noise }

class _ClassifiedFragment {
  final OcrFragment source;
  final _FragmentType type;

  /// Set when [type] == [_FragmentType.subject].
  final String? canonicalSubject;

  /// Set when [type] == [_FragmentType.grade]. Always a clean value like
  /// `"A"`, `"C+"`, `"B-"` — no parenthesised description.
  final String? gradeValue;

  const _ClassifiedFragment({
    required this.source,
    required this.type,
    this.canonicalSubject,
    this.gradeValue,
  });
}

// ── Parser ────────────────────────────────────────────────────────────────────

/// Parses an [OcrStructuredResult] into a [ParsedAcademicResult] containing
/// student identity fields and structured subject–grade pairs.
///
/// **Design goals**
///   • Reusable across any SPM result slip — no sample-specific logic.
///   • Tolerant of OCR noise, fragmented rows, and watermark artefacts.
///   • Decoupled from the subject dictionary: pass any catalog via
///     [SubjectCorrector].
///
/// **Overall algorithm**
///
///   1. **Student info** — anchored on the IC number (the only field with an
///      unmistakeable format). Name is found by scoring the 5 rows before the
///      IC row. Candidate ID is found in the 2 rows after it.
///
///   2. **Results** — all fragments from all rows are flattened and each is
///      classified as `subject`, `grade`, `description`, or `noise`. A state
///      machine then pairs each subject with the next grade that follows it
///      in document order, skipping any intervening noise/description
///      fragments. This handles:
///        - Normal rows: `MATHEMATICS  A (CEMERLANG TINGGI)` (two fragments)
///        - Orphan-grade rows: `SCIENCE` on one row, `C` on the next
///        - Watermark-split rows:
///            `BAHASA CINA` / `BERSEKUTU` / `B` / `(KEPUJIAN TINGGI)`
class AcademicResultParser {
  /// Fuzzy subject matcher supplied by the caller.
  ///
  /// Inject with the appropriate catalog, e.g.:
  /// ```dart
  /// SubjectCorrector(subjects: kSpmSubjects)
  /// ```
  final SubjectCorrector subjectCorrector;

  const AcademicResultParser({required this.subjectCorrector});

  // ── Regex constants ────────────────────────────────────────────────────────

  /// IC number: 6 digits, separator, 2 digits, separator, 4 digits.
  /// Accepts letter-O, letter-I, and letter-l as OCR substitutions for 0/1.
  static final RegExp _kIcPattern = RegExp(
    r'[0-9OIl]{6}[-\s][0-9OIl]{2}[-\s][0-9OIl]{4}',
  );

  /// SPM candidate ID: starts with 1–4 uppercase letters, followed by
  /// alphanumeric characters, total 6–12 characters, no spaces.
  static final RegExp _kCandidateIdPattern = RegExp(r'^[A-Z][A-Z0-9]{5,11}$');

  /// A fragment that is entirely a parenthesised grade description:
  /// `(KEPUJIAN)`, `(LULUS ATAS)`, `(CEMERLANG TINGGI)`.
  static final RegExp _kDescriptionPattern = RegExp(r'^\(.*\)$');

  /// Grade: letter A–E, optional +/-, optional parenthesised description.
  /// Groups: (1) grade letter, (2) optional +/-.
  /// `\s*` between letter and modifier tolerates OCR spaces (e.g. `A +`).
  static final RegExp _kGradePattern = RegExp(
    r'^([A-E])\s*([+\-]?)\s*(?:\([^)]*\))?$',
    caseSensitive: false,
  );

  // ── Noise token set ────────────────────────────────────────────────────────

  /// Individual words that definitively indicate non-result text.
  ///
  /// Only words that **never** appear in official SPM subject names are
  /// included, so that subjects like `Pendidikan Moral` or `Bahasa Inggeris`
  /// are not accidentally blocked.
  static const Set<String> _kNoiseTokens = {
    // Ministry / institution headers
    'kementerian', 'lembaga', 'examinations', 'syndicate', 'ministry',
    // Certificate boilerplate
    'calon', 'namanya', 'tercatat', 'bawah', 'telah', 'menduduki',
    'layak', 'dianugerahi', 'sijil',
    // Watermark / decorative text
    'bersekutu', 'pertabahan', 'mutu',
    // Table column headers
    'mata', 'gred', 'grade', 'subject',
    // Grade descriptions appearing as standalone fragments
    'kepujian', 'lulus', 'cemerlang', 'jaya',
    // Footer text
    'jumlah', 'pengarah', 'peperiksaan', 'tahun', 'director',
    // Number words that appear in "JUMLAH … SEMBILAN" etc.
    'sembilan', 'lapan', 'tujuh', 'enam', 'lima', 'empat', 'tiga',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Parses [ocrResult] and returns a [ParsedAcademicResult].
  ParsedAcademicResult parse(OcrStructuredResult ocrResult) {
    final List<OcrRow> rows = ocrResult.rows;
    return ParsedAcademicResult(
      studentInfo: _extractStudentInfo(rows),
      results: _extractResults(rows),
    );
  }

  // ── Student info extraction ────────────────────────────────────────────────

  StudentInfo? _extractStudentInfo(List<OcrRow> rows) {
    // Locate the IC row — the strongest structural anchor on any SPM cert.
    int icIndex = -1;
    String icNumber = '';

    for (int i = 0; i < rows.length; i++) {
      final match = _kIcPattern.firstMatch(rows[i].text);
      if (match != null) {
        icIndex = i;
        icNumber = _normaliseIc(match.group(0)!);
        break;
      }
    }

    if (icIndex < 0) return null;

    return StudentInfo(
      name: _extractName(rows, icIndex),
      ic: icNumber,
      candidateId: _extractCandidateId(rows, icIndex),
    );
  }

  /// Replaces common OCR digit substitutions and normalises separators.
  static String _normaliseIc(String raw) => raw
      .toUpperCase()
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll(RegExp(r'[\s—–]'), '-');

  /// Searches the 5 rows before [icIndex] and returns the row that best
  /// resembles a Malaysian name (letters/spaces, no digits, all caps,
  /// 2–4 words, not blacklisted).
  String _extractName(List<OcrRow> rows, int icIndex) {
    final int start = max(0, icIndex - 5);
    int bestIndex = -1;
    double bestScore = double.negativeInfinity;

    for (int i = start; i < icIndex; i++) {
      final double score = _nameScore(rows[i].text.trim());
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestIndex >= 0 ? rows[bestIndex].text.trim() : '';
  }

  /// Heuristic score for whether a text string looks like a person's name.
  ///
  /// Returns [double.negativeInfinity] for blacklisted or digit-heavy strings
  /// so they are never selected even when no better candidate exists.
  double _nameScore(String text) {
    if (text.isEmpty) return double.negativeInfinity;

    // Immediately reject blacklisted text (headers, footers, watermarks).
    if (_containsNoiseToken(text)) return double.negativeInfinity;

    double score = 0.0;

    // Penalise heavily for digits (IC numbers, cert serials, years).
    if (RegExp(r'[0-9]').hasMatch(text)) score -= 5.0;

    // Reward if composed only of letters, spaces, and name-punctuation.
    if (RegExp(r"^[A-Za-z\s@/'.\-]+$").hasMatch(text)) score += 3.0;

    // Reward all-uppercase text (SPM certificates print names in caps).
    if (text == text.toUpperCase() && RegExp(r'[A-Z]').hasMatch(text)) {
      score += 1.0;
    }

    // Reward reasonable name lengths.
    if (text.length >= 5 && text.length <= 50) score += 1.0;

    // Reward multi-word names (Malaysian names typically have 2–4 parts).
    final int words = text.trim().split(RegExp(r'\s+')).length;
    if (words >= 2) score += 1.0;
    if (words >= 3) score += 0.5;

    return score;
  }

  /// Checks the 2 rows after [icIndex] for an alphanumeric candidate ID.
  String _extractCandidateId(List<OcrRow> rows, int icIndex) {
    final int limit = min(icIndex + 3, rows.length);
    for (int i = icIndex + 1; i < limit; i++) {
      // Check full row text first.
      if (_kCandidateIdPattern.hasMatch(rows[i].text.trim())) {
        return rows[i].text.trim();
      }
      // Also check individual fragments in case the row merged extra text.
      for (final fragment in rows[i].fragments) {
        final t = fragment.text.trim();
        if (_kCandidateIdPattern.hasMatch(t)) return t;
      }
    }
    return '';
  }

  // ── Results extraction ─────────────────────────────────────────────────────

  List<AcademicResultEntry> _extractResults(List<OcrRow> rows) {
    // Flatten ALL fragments from ALL rows in document order (top-to-bottom,
    // left-to-right within each row).
    final List<OcrFragment> allFragments = [
      for (final row in rows) ...row.fragments,
    ];

    // Classify every fragment.
    final classified = allFragments.map(_classifyFragment).toList();

    // State machine: match each subject to the next grade that follows it,
    // skipping over any noise or description fragments in between.
    final List<AcademicResultEntry> results = [];
    String? pendingSubject;

    for (final cf in classified) {
      switch (cf.type) {
        case _FragmentType.subject:
          // A new subject replaces the previous pending subject.
          // If the previous subject never received a grade, it is discarded
          // (treated as an unmatched OCR artefact).
          pendingSubject = cf.canonicalSubject;
          break;

        case _FragmentType.grade:
          if (pendingSubject != null) {
            results.add(AcademicResultEntry(
              subject: pendingSubject,
              grade: cf.gradeValue!,
            ));
            pendingSubject = null;
          }
          // A grade with no preceding subject is an orphan — discard.
          break;

        case _FragmentType.description:
        case _FragmentType.noise:
          // Neither alters the pending state — the state machine skips over
          // watermarks, column headers, grade descriptions, and all other
          // non-result fragments transparently.
          break;
      }
    }

    // Deduplicate: watermark reflections can cause the same subject to appear
    // twice. Keep the first occurrence.
    final Set<String> seen = {};
    return results.where((r) => seen.add(r.subject)).toList();
  }

  // ── Fragment classification ────────────────────────────────────────────────

  _ClassifiedFragment _classifyFragment(OcrFragment fragment) {
    final String raw = fragment.text.trim();

    if (raw.isEmpty) {
      return _ClassifiedFragment(source: fragment, type: _FragmentType.noise);
    }

    // ── 1. Pure description: `(KEPUJIAN)`, `(LULUS ATAS)` etc. ─────────────
    if (_kDescriptionPattern.hasMatch(raw)) {
      return _ClassifiedFragment(
          source: fragment, type: _FragmentType.description);
    }

    // ── 2. Grade: letter A–E with optional +/- and optional description ─────
    //    Matched against the uppercased fragment to be case-insensitive.
    final gradeMatch = _kGradePattern.firstMatch(raw.toUpperCase());
    if (gradeMatch != null) {
      final String letter = gradeMatch.group(1)!.toUpperCase();
      final String modifier = gradeMatch.group(2) ?? '';
      final String gradeValue =
          (letter + modifier).replaceAll(' ', ''); // normalise "A +" → "A+"
      return _ClassifiedFragment(
        source: fragment,
        type: _FragmentType.grade,
        gradeValue: gradeValue,
      );
    }

    // ── 3. Noise token check ─────────────────────────────────────────────────
    //    Checked AFTER the grade pattern so that single-letter grades like
    //    "A", "B", "C" are never mistakenly caught as noise.
    if (_containsNoiseToken(raw)) {
      return _ClassifiedFragment(source: fragment, type: _FragmentType.noise);
    }

    // ── 4. Subject via fuzzy matching ────────────────────────────────────────
    //    Two-stage pipeline:
    //    • [SubjectCorrector]  — fixes OCR character-level noise
    //      (e.g. "BIOLLOGY" → "Biologi", "ADDTIONAL MATH" → "Matematik Tambahan").
    //    • [SubjectNormalizer] — maps language/alias differences to the canonical
    //      English name used in course conditions and stored in Firestore
    //      (e.g. "Biologi" → "Biology", "Bahasa Inggeris" → "English").
    final corrected = subjectCorrector.correct(raw);
    if (!corrected.isLowConfidence) {
      return _ClassifiedFragment(
        source: fragment,
        type: _FragmentType.subject,
        canonicalSubject: SubjectNormalizer.normalize(corrected.name),
      );
    }

    // ── 5. Everything else is noise ──────────────────────────────────────────
    return _ClassifiedFragment(source: fragment, type: _FragmentType.noise);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _containsNoiseToken(String text) {
    final normalized = text.toLowerCase().trim();
    return normalized.split(RegExp(r'\s+')).any(_kNoiseTokens.contains);
  }
}
