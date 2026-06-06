import '../models/course.dart';
import '../models/interest_match_result.dart';
import '../models/student_interest.dart';
import 'recommendation_engine.dart';

// =============================================================================
// RIASEC mapping
// =============================================================================

/// Single source of truth for translating a RIASEC letter code to the full
/// Holland category name stored in [Course.interestTags].
///
/// Student documents store letter codes (`"R"`, `"I"`, …`).
/// Course documents store full names (`"Realistic"`, `"Investigative"`, …`).
/// This map is the only place where that translation is defined — it is
/// never duplicated inside the engine, the screen, or any seeder.
const Map<String, String> kRiasecCodeToTagName = {
  'R': 'Realistic',
  'I': 'Investigative',
  'A': 'Artistic',
  'S': 'Social',
  'E': 'Enterprising',
  'C': 'Conventional',
};

/// Positional weights applied to each selected RIASEC code.
///
/// The student's selection order carries meaning — the first-tapped code is
/// the dominant interest and receives the highest weight.
///
/// | Index | Rank       | Weight |
/// |-------|------------|--------|
/// | 0     | dominant   |   3    |
/// | 1     | secondary  |   2    |
/// | 2     | tertiary   |   1    |
const List<int> kRiasecWeights = [3, 2, 1];

/// Maximum achievable interest score (3 + 2 + 1 when all three codes match).
const int kMaxInterestScore = 6;

// =============================================================================
// InterestMatcher
// =============================================================================

/// Computes career interest alignment between a student's RIASEC profile and
/// a course's [Course.interestTags].
///
/// This class is intentionally separate from [RecommendationEngine].  The
/// engine handles academic eligibility; [InterestMatcher] handles interest
/// scoring.  The two are composed in [RecommendationScreen] — the engine runs
/// first, then [InterestMatcher.wrap] is called on each eligible result.
///
/// ## Algorithm
///
/// For each of the student's three selected RIASEC codes (in selection order):
/// 1. Translate the letter code to its full name via [kRiasecCodeToTagName].
/// 2. Check whether [Course.interestTags] contains that name
///    (comparison is case-insensitive).
/// 3. If matched, add the positional weight (3 / 2 / 1) to the score.
///
/// Maximum score = 6.  Percent = `(score / 6) × 100`, rounded.
///
/// ## Null / incomplete profile handling
///
/// When [student] is `null` or [StudentInterest.isComplete] is `false`,
/// [computeScore] returns 0.  This causes all [InterestMatchResult.interestScore]
/// values to equal 0, which collapses the ranking sort to the secondary
/// criterion (course name ascending) — identical to the pre-interest behaviour.
class InterestMatcher {
  const InterestMatcher();

  // ---------------------------------------------------------------------------
  // computeScore
  // ---------------------------------------------------------------------------

  /// Returns the weighted interest score (0–6) for [course] against [student].
  ///
  /// Returns 0 immediately when [student] is `null` or incomplete.
  int computeScore(StudentInterest? student, Course course) {
    if (student == null || !student.isComplete) return 0;

    // Normalise course tags to lowercase once — avoids repeated .toLowerCase()
    // inside the loop and guards against capitalisation drift in Firestore.
    final courseTags =
        course.interestTags.map((t) => t.toLowerCase()).toSet();

    int score = 0;
    for (int i = 0; i < student.riasecCodes.length; i++) {
      final fullName = kRiasecCodeToTagName[student.riasecCodes[i]];
      if (fullName != null && courseTags.contains(fullName.toLowerCase())) {
        score += kRiasecWeights[i];
      }
    }
    return score;
  }

  // ---------------------------------------------------------------------------
  // computePercent
  // ---------------------------------------------------------------------------

  /// Converts a raw [score] (0–6) to an integer percentage (0–100).
  ///
  /// Formula: `(score / kMaxInterestScore) * 100`, rounded to the nearest int.
  int computePercent(int score) =>
      ((score / kMaxInterestScore) * 100).round();

  // ---------------------------------------------------------------------------
  // wrap
  // ---------------------------------------------------------------------------

  /// Wraps [evaluation] with interest-matching data computed from [student].
  ///
  /// [RecommendationEngine.evaluateCourse] is never called here — [evaluation]
  /// is the already-computed academic eligibility result passed in by the
  /// caller.  [InterestMatcher] only reads [evaluation.course.interestTags].
  InterestMatchResult wrap(
    CourseEvaluationResult evaluation,
    StudentInterest? student,
  ) {
    final score = computeScore(student, evaluation.course);
    return InterestMatchResult(
      evaluation: evaluation,
      interestScore: score,
      interestMatchPercent: computePercent(score),
    );
  }
}
