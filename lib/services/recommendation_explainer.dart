import '../models/academic_result_entry.dart';
import '../models/course_fit_result.dart';
import '../models/recommendation_explanation.dart';
import '../models/student_interest.dart';
import 'interest_matcher.dart';

// =============================================================================
// Lookup tables (mirrors private data in course_fit_matcher.dart)
// =============================================================================

/// Relevant SPM subjects for each course code's academic-strength explanation.
///
/// Mirrors the private `_kCategorySubjects` inside [CourseFitMatcher].
/// Defined independently here so [CourseFitMatcher] is not modified.
/// Keys are upper-cased course codes.
const Map<String, List<String>> _kExplainerSubjects = {
  'BDS':    ['Mathematics', 'Additional Mathematics'],
  'BSE':    ['Mathematics', 'Additional Mathematics'],
  'BITSSD': ['Mathematics', 'Additional Mathematics'],
  'BABA':   ['Mathematics', 'Additional Mathematics'],
  'BEET':   ['Mathematics', 'Additional Mathematics', 'Physics'],
  'BFI':    ['Mathematics'],
  'BBAF':   ['Mathematics'],
  'BBA':    ['Mathematics', 'English'],
  'BBIBM':  ['Mathematics', 'English'],
  'BPR':    ['English', 'Bahasa Melayu'],
};

/// Grade weights for explanation display — same as in [CourseFitMatcher].
const Map<String, int> _kExplainerWeights = {
  'A+': 5,
  'A':  5,
  'A-': 4,
  'B+': 4,
  'B':  3,
  'B-': 3,
  'C+': 2,
  'C':  1,
  'C-': 1,
};

// =============================================================================
// RecommendationExplainer
// =============================================================================

/// Builds a [RecommendationExplanation] from a pre-computed [CourseFitResult].
///
/// This class **does not recalculate any score**.  Every percentage value in
/// the returned explanation is sourced directly from [fitResult] and its
/// nested objects.  The explainer only organises existing data into a
/// human-readable structure that the UI expansion panel can render.
///
/// ## Inputs
///
/// | Parameter        | Source                                         |
/// |------------------|------------------------------------------------|
/// | [fitResult]      | Sprint-5 CourseFitResult (all scores computed) |
/// | [studentInterest]| Loaded from Firestore `studentInterests/{uid}` |
/// | [spmEntries]     | `engineInput['SPM']` extracted in the screen   |
///
/// ## Sections produced
///
/// 1. **Eligibility** — `matchedPathway.routeResults.keys.join(' + ')`
/// 2. **Interest Match** — student RIASEC names, course tags, matched overlap
/// 3. **Academic Strength** — relevant subjects and student's actual grades
/// 4. **Final Score** — interest %, academic %, overall %
class RecommendationExplainer {
  const RecommendationExplainer();

  // ---------------------------------------------------------------------------
  // explain
  // ---------------------------------------------------------------------------

  /// Produces a [RecommendationExplanation] for [fitResult].
  ///
  /// [spmEntries] should be `engineInput['SPM'] ?? const []`.
  /// An empty list is safe — subject grades will be shown as absent.
  RecommendationExplanation explain(
    CourseFitResult fitResult,
    StudentInterest? studentInterest,
    List<AcademicResultEntry> spmEntries,
  ) {
    // ── 1. Eligibility string ─────────────────────────────────────────────────
    final routeKeys =
        fitResult.evaluation.matchedPathway?.routeResults.keys.toList() ?? [];
    final eligibleVia =
        routeKeys.isNotEmpty ? routeKeys.join(' + ') : '—';

    // ── 2. Interest explanation ───────────────────────────────────────────────
    final hasProfile = studentInterest != null && studentInterest.isComplete;

    final studentInterestNames = hasProfile
        ? studentInterest.riasecCodes
            .map((c) => kRiasecCodeToTagName[c] ?? c)
            .toList()
        : const <String>[];

    // Build a lowercase set of course tags for case-insensitive intersection.
    final courseTagsLower =
        fitResult.course.interestTags.map((t) => t.toLowerCase()).toSet();

    // Keep original casing from studentInterestNames for display.
    final matchedInterestTags = studentInterestNames
        .where((name) => courseTagsLower.contains(name.toLowerCase()))
        .toList();

    // ── 3. Academic explanation ───────────────────────────────────────────────
    final relevantSubjects =
        _kExplainerSubjects[fitResult.course.code.toUpperCase()] ??
        const <String>[];

    // Case-insensitive subject → grade lookup, built once.
    final gradeMap = <String, String>{
      for (final e in spmEntries) e.subject.trim().toLowerCase(): e.grade,
    };

    final subjectFits = relevantSubjects.map((subject) {
      final grade = gradeMap[subject.toLowerCase()];
      final weight = grade != null
          ? (_kExplainerWeights[grade.trim().toUpperCase()] ?? 0)
          : 0;
      return SubjectFitEntry(subject: subject, grade: grade, weight: weight);
    }).toList();

    // ── 4. Assemble ───────────────────────────────────────────────────────────
    return RecommendationExplanation(
      courseName: fitResult.course.name,
      eligibleVia: eligibleVia,
      hasInterestProfile: hasProfile,
      studentInterestNames: studentInterestNames,
      courseInterestTags: List.unmodifiable(fitResult.course.interestTags),
      matchedInterestTags: matchedInterestTags,
      interestMatchPercent: fitResult.interestMatchPercent,
      subjectFits: subjectFits,
      academicFitPercent: fitResult.academicStrengthPercent,
      overallMatchPercent: fitResult.overallMatchPercent,
    );
  }
}
