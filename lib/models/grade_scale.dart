/// TARUMT-style requirement threshold used in course admission conditions.
///
/// Stored as the `"grade"` field inside a condition entry when the
/// qualification is `"SPM"`, e.g.
/// `{ "qualification": "SPM", "subject": "Mathematics", "grade": "Credit" }`.
enum RequirementGrade {
  /// Student must have obtained grade C or better (rank ≤ 8).
  credit,

  /// Student must have obtained grade E or better (rank ≤ 10).
  pass,
}

/// Pure-logic, stateless helper for SPM letter-grade comparisons used by the
/// recommendation engine.
///
/// ### Grade ranking table
///
/// | Grade | Rank | Credit? | Pass? |
/// |-------|------|---------|-------|
/// | A+    |  1   |   yes   |  yes  |
/// | A     |  2   |   yes   |  yes  |
/// | A-    |  3   |   yes   |  yes  |
/// | B+    |  4   |   yes   |  yes  |
/// | B     |  5   |   yes   |  yes  |
/// | B-    |  6   |   yes   |  yes  |
/// | C+    |  7   |   yes   |  yes  |
/// | C     |  8   |   yes   |  yes  |
/// | D     |  9   |   no    |  yes  |
/// | E     | 10   |   no    |  yes  |
/// | G     | 11   |   no    |  no   |
///
/// Lower rank = better grade.  A student grade satisfies a requirement when
/// `studentRank ≤ thresholdRank`.
///
/// ### Requirement thresholds
///
/// | Requirement          | Minimum grade | Threshold rank |
/// |----------------------|---------------|----------------|
/// | [RequirementGrade.credit] | C        |  8             |
/// | [RequirementGrade.pass]   | E        | 10             |
///
/// ### [meetsRequirement] dual-mode behaviour
///
/// `requiredGrade` accepts either:
/// - A TARUMT requirement keyword (`"Credit"` / `"Pass"`) — resolved to the
///   corresponding [RequirementGrade] threshold.
/// - A direct letter grade (`"A"`, `"C+"`, etc.) — compared rank-to-rank.
///
/// This matches the two value shapes that appear in `Course.admissionPathways`
/// condition entries (see `course.dart`).
class GradeScale {
  // Prevent instantiation — this class is a pure static utility.
  GradeScale._();

  // ---------------------------------------------------------------------------
  // Internal tables
  // ---------------------------------------------------------------------------

  /// Ordered rank map.  All keys are already upper-cased canonical forms.
  static const Map<String, int> _rankMap = {
    'A+': 1,
    'A': 2,
    'A-': 3,
    'B+': 4,
    'B': 5,
    'B-': 6,
    'C+': 7,
    'C': 8,
    'D': 9,
    'E': 10,
    'G': 11,
  };

  /// Threshold ranks for TARUMT requirement keywords.
  ///
  /// A student satisfies the requirement when `studentRank ≤ thresholdRank`.
  static const Map<RequirementGrade, int> _thresholdRank = {
    RequirementGrade.credit: 8, // grade must be C or better
    RequirementGrade.pass: 10, // grade must be E or better
  };

  // ---------------------------------------------------------------------------
  // Public helpers
  // ---------------------------------------------------------------------------

  /// Normalizes a raw grade string to its canonical upper-case form.
  ///
  /// Strips surrounding whitespace and converts to upper case so that `"a+"`,
  /// `" B- "`, and `"c"` resolve correctly to `"A+"`, `"B-"`, `"C"`.
  static String normalizeGrade(String grade) => grade.trim().toUpperCase();

  /// Returns the numeric rank for [grade] (lower rank = better grade).
  ///
  /// [grade] is normalised before lookup, so case and surrounding whitespace
  /// are ignored.
  ///
  /// Throws [ArgumentError] when [grade] is not one of the 11 known grades.
  ///
  /// ```dart
  /// GradeScale.getGradeRank('A+'); // 1
  /// GradeScale.getGradeRank('c'); // 8  (normalised to "C")
  /// GradeScale.getGradeRank('G'); // 11
  /// ```
  static int getGradeRank(String grade) {
    final canonical = normalizeGrade(grade);
    final rank = _rankMap[canonical];
    if (rank == null) {
      throw ArgumentError.value(
        grade,
        'grade',
        'Unrecognised grade "$grade". '
            'Expected one of: ${_rankMap.keys.join(', ')}.',
      );
    }
    return rank;
  }

  /// Returns `true` when [studentGrade] satisfies [requiredGrade].
  ///
  /// Three evaluation modes are tried in order:
  ///
  /// **1 — TARUMT keyword mode** — if [requiredGrade] is `"Credit"` or
  /// `"Pass"` (case-insensitive), the student grade is compared against the
  /// fixed threshold rank:
  ///
  /// ```dart
  /// GradeScale.meetsRequirement(requiredGrade: 'Credit', studentGrade: 'C');  // true
  /// GradeScale.meetsRequirement(requiredGrade: 'Credit', studentGrade: 'D');  // false
  /// GradeScale.meetsRequirement(requiredGrade: 'Pass',   studentGrade: 'E');  // true
  /// GradeScale.meetsRequirement(requiredGrade: 'Pass',   studentGrade: 'G');  // false
  /// ```
  ///
  /// **2 — Letter-grade mode** — if both grades are recognised letter grades
  /// (`"A+"` … `"G"`), their ranks are compared directly:
  ///
  /// ```dart
  /// GradeScale.meetsRequirement(requiredGrade: 'C', studentGrade: 'B'); // true  (5 ≤ 8)
  /// GradeScale.meetsRequirement(requiredGrade: 'C', studentGrade: 'D'); // false (9 > 8)
  /// ```
  ///
  /// **3 — Numeric mode** — when [studentGrade] is not a recognised letter
  /// grade (e.g. MUET `"Band 3.0"`, IELTS `"5.5"`, LINGUASKILL `"130"`),
  /// both values are stripped of a leading `"Band "` prefix and parsed as
  /// doubles.  The student satisfies the requirement when
  /// `studentValue >= requiredValue`:
  ///
  /// ```dart
  /// GradeScale.meetsRequirement(requiredGrade: 'Band 2.0', studentGrade: 'Band 3.0'); // true
  /// GradeScale.meetsRequirement(requiredGrade: '3.0',      studentGrade: '5.5');       // true
  /// GradeScale.meetsRequirement(requiredGrade: '127',      studentGrade: '100');       // false
  /// ```
  ///
  /// Returns `false` (never throws) when no mode can resolve the grades.
  static bool meetsRequirement({
    required String requiredGrade,
    required String studentGrade,
  }) {
    // ── Mode 1 & 2: letter / keyword ─────────────────────────────────────────
    final studentRank = _rankMap[normalizeGrade(studentGrade)];
    if (studentRank != null) {
      final requirement = _parseRequirementKeyword(requiredGrade);
      if (requirement != null) {
        return studentRank <= _thresholdRank[requirement]!;
      }
      final requiredRank = _rankMap[normalizeGrade(requiredGrade)];
      if (requiredRank != null) {
        return studentRank <= requiredRank;
      }
      // Student has a recognised letter grade but required grade is unknown.
      return false;
    }

    // ── Mode 3: numeric — MUET Band X.X, IELTS X.X, LINGUASKILL XXX ──────────
    final reqNum = _parseNumericGrade(requiredGrade);
    final stuNum = _parseNumericGrade(studentGrade);
    if (reqNum != null && stuNum != null) return stuNum >= reqNum;

    return false;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Strips a leading `"Band "` prefix and parses the remainder as a [double].
  ///
  /// Handles MUET (`"Band 2.0"` → `2.0`), IELTS (`"3.0"` → `3.0`), and
  /// LINGUASKILL (`"127"` → `127.0`).  Returns `null` when the value cannot
  /// be parsed as a number.
  static double? _parseNumericGrade(String value) {
    final stripped = value.trim().toLowerCase().replaceAll('band ', '');
    return double.tryParse(stripped);
  }

  /// Attempts to parse [value] as a [RequirementGrade] keyword.
  ///
  /// Returns `null` when [value] is not a recognised keyword.
  static RequirementGrade? _parseRequirementKeyword(String value) {
    switch (value.trim().toLowerCase()) {
      case 'credit':
        return RequirementGrade.credit;
      case 'pass':
        return RequirementGrade.pass;
      default:
        return null;
    }
  }
}
