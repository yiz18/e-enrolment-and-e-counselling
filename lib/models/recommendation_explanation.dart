/// A single SPM subject entry in the academic-strength explanation.
///
/// [grade] is `null` when the subject was not found in the student's results.
/// [weight] is 0 in that case regardless of any weight-table lookup.
class SubjectFitEntry {
  final String subject;

  /// The student's actual grade for this subject, or `null` if absent.
  final String? grade;

  /// Academic-strength weight (0–5) derived from [grade].
  final int weight;

  const SubjectFitEntry({
    required this.subject,
    required this.grade,
    required this.weight,
  });

  /// `true` when the subject was found in the student's SPM results.
  bool get found => grade != null;
}

/// Explanation data for a single course recommendation.
///
/// Immutable.  Built by [RecommendationExplainer.explain].
/// Consumed by the expandable explanation panel inside [RecommendationScreen].
///
/// ### Sections
///
/// | Section          | Condition to show          |
/// |------------------|----------------------------|
/// | Eligibility      | Always                     |
/// | Interest Match   | [hasInterestProfile] == true |
/// | Academic Strength| Always                     |
/// | Final Score      | Always                     |
class RecommendationExplanation {
  final String courseName;

  /// Qualification(s) through which the student is eligible.
  ///
  /// Derived from [CourseEvaluationResult.matchedPathway.routeResults.keys].
  /// Examples: `"SPM"`, `"Foundation"`, `"SPM + MUET"`.
  final String eligibleVia;

  // ── Interest section ───────────────────────────────────────────────────────

  /// `true` when the student has a complete RIASEC profile.
  ///
  /// When `false`, [studentInterestNames] and [matchedInterestTags] are empty
  /// and the Interest Match section must not be rendered.
  final bool hasInterestProfile;

  /// Student's RIASEC category names in priority order (dominant first).
  ///
  /// e.g. `["Investigative", "Enterprising", "Realistic"]`
  /// Empty list when [hasInterestProfile] is `false`.
  final List<String> studentInterestNames;

  /// The course's declared interest tags (full Holland names).
  ///
  /// e.g. `["Investigative", "Conventional", "Realistic"]`
  final List<String> courseInterestTags;

  /// Tags present in both [studentInterestNames] and [courseInterestTags].
  final List<String> matchedInterestTags;

  final int interestMatchPercent;

  // ── Academic section ───────────────────────────────────────────────────────

  /// Relevant SPM subjects for this course category, each paired with the
  /// student's grade (or `null` when the subject was absent).
  ///
  /// Only the subjects used for academic-strength scoring are included.
  /// Empty when the course has no recognised category mapping.
  final List<SubjectFitEntry> subjectFits;

  final int academicFitPercent;

  // ── Combined section ───────────────────────────────────────────────────────

  final int overallMatchPercent;

  const RecommendationExplanation({
    required this.courseName,
    required this.eligibleVia,
    required this.hasInterestProfile,
    required this.studentInterestNames,
    required this.courseInterestTags,
    required this.matchedInterestTags,
    required this.interestMatchPercent,
    required this.subjectFits,
    required this.academicFitPercent,
    required this.overallMatchPercent,
  });
}
