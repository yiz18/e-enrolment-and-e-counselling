import 'course.dart';
import 'interest_match_result.dart';
import '../services/recommendation_engine.dart';

/// Extends [InterestMatchResult] with an academic-strength score derived from
/// the student's actual SPM subject grades.
///
/// Created by [CourseFitMatcher.compute] after [InterestMatcher.wrap].
/// [RecommendationEngine] and [InterestMatcher] are never modified.
///
/// ### Score fields
///
/// | Field                     | Range  | Description                                          |
/// |---------------------------|--------|------------------------------------------------------|
/// | [academicStrengthScore]   | 0–max  | Raw sum of grade weights for relevant SPM subjects.  |
/// | [academicStrengthPercent] | 0–100  | [academicStrengthScore] as a % of the maximum possible. |
/// | [overallMatchPercent]     | 0–100  | interest × 0.5 + academic × 0.5, rounded.            |
///
/// ### Maximum raw score per programme category
///
/// | Category        | Subjects                              | Max score |
/// |-----------------|---------------------------------------|-----------|
/// | Computing       | Mathematics, Additional Mathematics   | 10        |
/// | Engineering     | Mathematics, Add Maths, Physics       | 15        |
/// | Finance         | Mathematics                           | 5         |
/// | Business        | Mathematics, English                  | 10        |
/// | Public Relations| English, Bahasa Melayu                | 10        |
/// | Unrecognised    | —                                     | 0         |
class CourseFitResult {
  /// The wrapped RIASEC interest-match result (eligibility + interest score).
  final InterestMatchResult interestResult;

  /// Raw sum of grade weights for the relevant SPM subjects.
  final int academicStrengthScore;

  /// Academic strength expressed as an integer percentage (0–100).
  ///
  /// Formula: `(academicStrengthScore / maxPossibleScore) × 100`, rounded.
  /// Zero when no relevant subjects are defined for the course category.
  final int academicStrengthPercent;

  /// Final combined match expressed as an integer percentage (0–100).
  ///
  /// Formula: `(interestMatchPercent × 0.5) + (academicStrengthPercent × 0.5)`,
  /// rounded to the nearest integer.  Equal weighting reflects the project's
  /// dual emphasis on academic performance and career interests.
  final int overallMatchPercent;

  const CourseFitResult({
    required this.interestResult,
    required this.academicStrengthScore,
    required this.academicStrengthPercent,
    required this.overallMatchPercent,
  });

  // Convenience delegates so UI widgets never need to double-dereference.
  Course get course => interestResult.course;
  CourseEvaluationResult get evaluation => interestResult.evaluation;
  int get interestMatchPercent => interestResult.interestMatchPercent;
  int get interestScore => interestResult.interestScore;
}
