import 'dart:math';

import '../models/corrected_subject.dart';

/// Corrects an OCR-extracted subject name by fuzzy-matching it against a
/// caller-supplied subject dictionary.
///
/// **Decoupling**: this class knows nothing about SPM, STPM, or any specific
/// qualification. Pass [kSpmSubjects], [kStpmSubjects], or any custom list
/// from `subject_catalogs.dart` and the same algorithm applies unchanged.
///
/// **Algorithm** (two-pass, take-the-max):
///
///   Pass 1 — Whole-string Levenshtein similarity
///     Compares the entire normalised OCR string against each canonical
///     subject name. Works well for single-word subjects with character-level
///     noise (e.g. "Phsics" → "Physics", edit distance = 1).
///
///   Pass 2 — Token similarity
///     Splits both strings on whitespace and finds the best per-token match
///     using Levenshtein, plus a configurable prefix bonus for truncated
///     words (e.g. "Math" → "Mathematics"). Scores = average over canonical
///     tokens. Works well for multi-word subjects where the whole-string
///     score is deflated by length differences.
///
///   Final score = max(Pass 1, Pass 2)
///   Accept if score ≥ [acceptanceThreshold]; otherwise return raw text.
///
/// **Usage**
/// ```dart
/// import '../data/subject_catalogs.dart';
///
/// final corrector = SubjectCorrector(subjects: kSpmSubjects);
/// final result = corrector.correct('Phsics');
/// // CorrectedSubject(name: "Physics", confidence: 0.857, isCorrected: true)
/// ```
class SubjectCorrector {
  /// The subject dictionary to match against. Must not be empty.
  ///
  /// Supply [kSpmSubjects], [kStpmSubjects], [kFoundationSubjects], or any
  /// custom list from `subject_catalogs.dart`.
  final List<String> subjects;

  /// Minimum combined similarity score [0.0, 1.0] required to accept a
  /// dictionary match.
  ///
  /// Raise toward 1.0 to reduce false positives on clean documents.
  /// Lower toward 0.4 if OCR quality is consistently poor.
  /// Default: 0.55
  final double acceptanceThreshold;

  /// Score assigned when an OCR token is a prefix of a canonical token and
  /// meets [minPrefixLength]. Compensates for truncated words that would
  /// otherwise score poorly on edit distance (e.g. "Math" vs "Mathematics":
  /// Levenshtein similarity = 0.36, prefix bonus = 0.75).
  ///
  /// Default: 0.75
  final double prefixMatchBonus;

  /// Minimum character length an OCR token must have to qualify for the
  /// prefix bonus. Prevents single-character noise from triggering spurious
  /// prefix matches.
  ///
  /// Default: 4
  final int minPrefixLength;

  const SubjectCorrector({
    required this.subjects,
    this.acceptanceThreshold = 0.55,
    this.prefixMatchBonus = 0.75,
    this.minPrefixLength = 4,
  });

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Attempts to correct [rawText] to the closest canonical subject name in
  /// [subjects].
  ///
  /// Always returns a [CorrectedSubject]. Check [CorrectedSubject.isCorrected]
  /// to determine whether a confident match was found, and
  /// [CorrectedSubject.isLowConfidence] to decide whether to flag the entry
  /// for manual review.
  CorrectedSubject correct(String rawText) {
    final String normalizedInput = normalize(rawText);

    if (normalizedInput.isEmpty || subjects.isEmpty) {
      return CorrectedSubject(
        name: rawText,
        confidence: 0.0,
        isCorrected: false,
        rawInput: rawText,
      );
    }

    String bestSubject = '';
    double bestScore = 0.0;

    for (final subject in subjects) {
      final double score = _combinedScore(normalizedInput, subject);
      if (score > bestScore) {
        bestScore = score;
        bestSubject = subject;
      }
    }

    if (bestScore >= acceptanceThreshold) {
      // isCorrected is false when the OCR text was already the canonical name.
      final bool changed = normalizedInput != normalize(bestSubject);
      return CorrectedSubject(
        name: bestSubject,
        confidence: bestScore,
        isCorrected: changed,
        rawInput: rawText,
      );
    }

    return CorrectedSubject(
      name: rawText,
      confidence: bestScore,
      isCorrected: false,
      rawInput: rawText,
    );
  }

  // ── Scoring ────────────────────────────────────────────────────────────────

  /// Returns max(wholeStringScore, tokenScore) for [normalizedOcr] vs [subject].
  double _combinedScore(String normalizedOcr, String subject) {
    final String normalizedSubject = normalize(subject);
    final double wholeScore =
        _levenshteinSimilarity(normalizedOcr, normalizedSubject);
    final double tokenScore =
        _tokenSimilarity(normalizedOcr, normalizedSubject);
    return max(wholeScore, tokenScore);
  }

  /// Normalised Levenshtein similarity in [0.0, 1.0].
  ///
  /// 1.0 = identical strings; 0.0 = no characters in common.
  double _levenshteinSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final int dist = _levenshteinDistance(a, b);
    final int maxLen = max(a.length, b.length);
    return maxLen == 0 ? 1.0 : 1.0 - dist / maxLen;
  }

  /// Token-based similarity between [normalizedOcr] and [normalizedSubject].
  ///
  /// Computes both directions and returns `min(recall, precision)`:
  ///
  ///   **Recall** — for each canonical token, the best match score among all
  ///   OCR tokens (augmented by a prefix bonus). Measures how completely the
  ///   canonical subject is covered by the OCR text.
  ///
  ///   **Precision** — for each OCR token, the best match score among all
  ///   canonical tokens. Measures how much of the OCR text is explained by
  ///   the canonical subject.
  ///
  /// Taking the minimum penalises two failure modes:
  ///   • A long noisy OCR string that contains one perfect match but many
  ///     unrelated tokens (e.g. "SMK SAINS KUCHING" vs "Sains" — recall = 1.0
  ///     but precision ≈ 0.43 → min = 0.43, correctly rejected).
  ///   • A very short OCR fragment that partially covers a long canonical name
  ///     (precision high, recall low → min is low).
  double _tokenSimilarity(String normalizedOcr, String normalizedSubject) {
    final List<String> ocrTokens = _tokenize(normalizedOcr);
    final List<String> subjectTokens = _tokenize(normalizedSubject);

    if (ocrTokens.isEmpty || subjectTokens.isEmpty) return 0.0;

    // Recall: how well each canonical token is covered by OCR tokens.
    double recallSum = 0.0;
    for (final subjectToken in subjectTokens) {
      double best = 0.0;
      for (final ocrToken in ocrTokens) {
        double score = _levenshteinSimilarity(ocrToken, subjectToken);
        if (subjectToken.startsWith(ocrToken) &&
            ocrToken.length >= minPrefixLength) {
          score = max(score, prefixMatchBonus);
        }
        best = max(best, score);
      }
      recallSum += best;
    }
    final double recall = recallSum / subjectTokens.length;

    // Precision: how well each OCR token is explained by canonical tokens.
    double precisionSum = 0.0;
    for (final ocrToken in ocrTokens) {
      double best = 0.0;
      for (final subjectToken in subjectTokens) {
        best = max(best, _levenshteinSimilarity(ocrToken, subjectToken));
      }
      precisionSum += best;
    }
    final double precision = precisionSum / ocrTokens.length;

    return min(recall, precision);
  }

  // ── Levenshtein distance ───────────────────────────────────────────────────

  /// Computes edit distance between [a] and [b] using a memory-efficient
  /// single-row dynamic programming implementation — O(min(|a|,|b|)) space.
  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Place the shorter string along the column axis to minimise the row size.
    if (a.length > b.length) return _levenshteinDistance(b, a);

    final List<int> row = List.generate(b.length + 1, (i) => i);

    for (int i = 1; i <= a.length; i++) {
      int prev = row[0]; // cell (i-1, j-1) before column j is processed
      row[0] = i;        // cost of deleting all of a[0..i]

      for (int j = 1; j <= b.length; j++) {
        final int temp = row[j];
        row[j] = a[i - 1] == b[j - 1]
            ? prev                                      // no edit needed
            : 1 + min(prev, min(row[j], row[j - 1])); // sub / del / ins
        prev = temp;
      }
    }

    return row[b.length];
  }

  // ── Normalisation ──────────────────────────────────────────────────────────

  /// Lowercases [text], strips all characters that are not ASCII letters,
  /// digits, or spaces, then collapses runs of whitespace and trims.
  ///
  /// Exposed as a public static so callers can pre-normalise input before
  /// building a [SubjectCorrector], and for unit-testing.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Splits a normalised string into non-empty tokens.
  static List<String> _tokenize(String normalized) =>
      normalized.split(' ').where((t) => t.isNotEmpty).toList();
}
