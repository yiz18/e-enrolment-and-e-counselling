import '../models/academic_result_entry.dart';
import '../models/course_fit_result.dart';
import '../models/interest_match_result.dart';

// =============================================================================
// Grade weight table
// =============================================================================

/// Maps SPM letter grades to an academic-strength weight (0–5).
///
/// | Grade | Weight | Notes                         |
/// |-------|--------|-------------------------------|
/// | A+    | 5      | Full marks                    |
/// | A     | 5      | Full marks                    |
/// | A-    | 4      |                               |
/// | B+    | 4      |                               |
/// | B     | 3      |                               |
/// | B-    | 3      |                               |
/// | C+    | 2      |                               |
/// | C     | 1      |                               |
/// | C-    | 1      | Included for completeness;    |
/// |       |        | not produced by OCR pipeline  |
/// | D/E/G | 0      | Below Credit threshold        |
/// | Other | 0      | Unrecognised / absent         |
const Map<String, int> _kGradeWeights = {
  'A+': 5,
  'A': 5,
  'A-': 4,
  'B+': 4,
  'B': 3,
  'B-': 3,
  'C+': 2,
  'C': 1,
  'C-': 1,
};

// =============================================================================
// Category → relevant subjects
// =============================================================================

/// Maps a programme category key to the list of SPM subjects scored.
///
/// Maximum per subject = 5 (A+ / A grade), therefore:
/// - Computing (2 subjects):        max = 10
/// - Engineering (3 subjects):      max = 15
/// - Finance (1 subject):           max =  5
/// - Business (2 subjects):         max = 10
/// - Public Relations (2 subjects): max = 10
const Map<String, List<String>> _kCategorySubjects = {
  'computing': ['Mathematics', 'Additional Mathematics'],
  'engineering': ['Mathematics', 'Additional Mathematics', 'Physics'],
  'finance': ['Mathematics'],
  'business': ['Mathematics', 'English'],
  'publicRelations': ['English', 'Bahasa Melayu'],
};

// =============================================================================
// CourseFitMatcher
// =============================================================================

/// Computes an academic-strength score for eligible courses based on the
/// student's actual SPM grades.
///
/// This is a post-processing step that runs after [InterestMatcher.wrap].
/// [RecommendationEngine] and [InterestMatcher] are never touched.
///
/// ## Algorithm
///
/// 1. Resolve the course category from [Course.code] (see table below).
/// 2. For each relevant subject, look up the student's SPM grade
///    (case-insensitive, whitespace-tolerant subject match).
/// 3. Map each grade to its weight via [_kGradeWeights].
/// 4. Sum the weights → [CourseFitResult.academicStrengthScore].
/// 5. Divide by the maximum possible score and express as a percentage →
///    [CourseFitResult.academicStrengthPercent].
/// 6. Combine with the existing interest score:
///    `overallMatchPercent = interestMatchPercent × 0.5 + academicStrengthPercent × 0.5`
///
/// ## Course-code → category mapping
///
/// | Category        | Course codes              |
/// |-----------------|---------------------------|
/// | Computing       | BDS, BSE, BITSSD, BABA    |
/// | Engineering     | BEET                      |
/// | Finance         | BFI, BBAF                 |
/// | Business        | BBA, BBIBM                |
/// | Public Relations| BPR                       |
/// | Unrecognised    | (all others) → score = 0  |
class CourseFitMatcher {
  const CourseFitMatcher();

  // ---------------------------------------------------------------------------
  // _resolveCategory
  // ---------------------------------------------------------------------------

  /// Returns the relevant-subject list and maximum achievable raw score for
  /// [courseCode].
  ///
  /// Returns an empty list and 0 for unrecognised codes, which causes
  /// [CourseFitResult.academicStrengthPercent] to be 0 for those courses.
  ({List<String> subjects, int maxScore}) _resolveCategory(String courseCode) {
    switch (courseCode.toUpperCase()) {
      case 'BDS':
      case 'BSE':
      case 'BITSSD':
      case 'BABA':
        final subs = _kCategorySubjects['computing']!;
        return (subjects: subs, maxScore: subs.length * 5);

      case 'BEET':
        final subs = _kCategorySubjects['engineering']!;
        return (subjects: subs, maxScore: subs.length * 5);

      case 'BFI':
      case 'BBAF':
        final subs = _kCategorySubjects['finance']!;
        return (subjects: subs, maxScore: subs.length * 5);

      case 'BBA':
      case 'BBIBM':
        final subs = _kCategorySubjects['business']!;
        return (subjects: subs, maxScore: subs.length * 5);

      case 'BPR':
        final subs = _kCategorySubjects['publicRelations']!;
        return (subjects: subs, maxScore: subs.length * 5);

      default:
        return (subjects: const <String>[], maxScore: 0);
    }
  }

  // ---------------------------------------------------------------------------
  // _gradeWeight
  // ---------------------------------------------------------------------------

  /// Returns the academic-strength weight for [grade] (0–5).
  ///
  /// [grade] is trimmed and upper-cased before lookup.
  /// Returns 0 for any unrecognised or absent grade.
  int _gradeWeight(String grade) =>
      _kGradeWeights[grade.trim().toUpperCase()] ?? 0;

  // ---------------------------------------------------------------------------
  // compute
  // ---------------------------------------------------------------------------

  /// Wraps [interestResult] with an academic-strength layer computed from
  /// [spmEntries].
  ///
  /// [spmEntries] must contain the student's SPM [AcademicResultEntry] list —
  /// typically `engineInput['SPM'] ?? const []`.  An empty list is safe:
  /// all relevant subjects will score 0.
  ///
  /// ### Example — BDS (Computing)
  ///
  /// Relevant subjects: Mathematics, Additional Mathematics  (max = 10)
  ///
  /// | Subject              | Student Grade | Weight |
  /// |----------------------|---------------|--------|
  /// | Mathematics          | A+            | 5      |
  /// | Additional Mathematics | A           | 5      |
  /// | **Total**            |               | **10** |
  ///
  /// academicStrengthPercent = (10 / 10) × 100 = **100%**
  CourseFitResult compute(
    InterestMatchResult interestResult,
    List<AcademicResultEntry> spmEntries,
  ) {
    final category = _resolveCategory(interestResult.course.code);

    int rawScore = 0;

    if (category.subjects.isNotEmpty) {
      // Build a case-insensitive subject → grade lookup map once.
      final gradeMap = <String, String>{
        for (final e in spmEntries) e.subject.trim().toLowerCase(): e.grade,
      };

      for (final subject in category.subjects) {
        final grade = gradeMap[subject.toLowerCase()];
        if (grade != null) {
          rawScore += _gradeWeight(grade);
        }
      }
    }

    final academicPercent = category.maxScore > 0
        ? ((rawScore / category.maxScore) * 100).round()
        : 0;

    // finalScore = interest × 0.5 + academic × 0.5  (equal weighting)
    final overallPercent =
        (interestResult.interestMatchPercent * 0.5 + academicPercent * 0.5)
            .round();

    return CourseFitResult(
      interestResult: interestResult,
      academicStrengthScore: rawScore,
      academicStrengthPercent: academicPercent,
      overallMatchPercent: overallPercent,
    );
  }
}
