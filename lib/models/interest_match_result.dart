import 'course.dart';
import '../services/recommendation_engine.dart';

/// Wraps a [CourseEvaluationResult] with career interest-matching metadata.
///
/// [RecommendationEngine] is not modified — it remains a pure academic
/// eligibility evaluator.  [InterestMatchResult] is a post-processing layer
/// that [InterestMatcher] attaches to each eligible [CourseEvaluationResult]
/// after the engine has finished.
///
/// ### Scoring reference
///
/// The student selects exactly three RIASEC codes in priority order.
/// Each code is weighted by its selection position:
///
/// | Position | Weight |
/// |----------|--------|
/// | 0 (dominant)  | 3 |
/// | 1 (secondary) | 2 |
/// | 2 (tertiary)  | 1 |
///
/// Maximum score = 6 (all three codes match the course's tags at full weight).
///
/// | [interestScore] | [interestMatchPercent] |
/// |-----------------|------------------------|
/// | 0               | 0%                     |
/// | 1               | 17%                    |
/// | 2               | 33%                    |
/// | 3               | 50%                    |
/// | 4               | 67%                    |
/// | 5               | 83%                    |
/// | 6               | 100%                   |
class InterestMatchResult {
  /// The underlying academic eligibility result from [RecommendationEngine].
  ///
  /// Never modified — always reflects the exact output of
  /// [RecommendationEngine.evaluateCourse].
  final CourseEvaluationResult evaluation;

  /// Weighted career interest alignment score, 0–6.
  ///
  /// 0 = no overlap between the student's RIASEC codes and the course tags.
  /// 6 = all three codes match at full positional weight.
  final int interestScore;

  /// Integer percentage derived from [interestScore].
  ///
  /// Formula: `(interestScore / 6) * 100`, rounded to the nearest integer.
  /// Range: 0–100 inclusive.
  final int interestMatchPercent;

  const InterestMatchResult({
    required this.evaluation,
    required this.interestScore,
    required this.interestMatchPercent,
  });

  /// Convenience accessor — delegates to [evaluation.course].
  Course get course => evaluation.course;
}
