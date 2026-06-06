import '../models/academic_result_entry.dart';
import '../models/course.dart';
import '../models/grade_scale.dart';

// =============================================================================
// Result value types
// =============================================================================

/// Outcome of evaluating one condition entry against the student's grades.
///
/// A condition entry has the shape:
/// ```
/// { "qualification": "SPM", "subject": "Mathematics", "grade": "Credit" }
/// ```
class ConditionResult {
  /// Raw condition map from [Course.admissionPathways].
  final Map<String, dynamic> condition;

  /// Whether the student satisfied this condition.
  final bool satisfied;

  /// The grade the student achieved for this subject, or `null` when the
  /// subject was absent from the student's results.
  final String? studentGrade;

  const ConditionResult({
    required this.condition,
    required this.satisfied,
    this.studentGrade,
  });

  /// Convenience accessors into the raw [condition] map.
  String get subject => condition['subject'] as String? ?? '';
  String get requiredGrade => condition['grade'] as String? ?? '';
  String get qualification => condition['qualification'] as String? ?? 'SPM';

  @override
  String toString() =>
      'ConditionResult('
      'subject: "$subject", '
      'required: "$requiredGrade", '
      'studentGrade: ${studentGrade != null ? '"$studentGrade"' : 'none'}, '
      'satisfied: $satisfied'
      ')';
}

/// Outcome of evaluating one AND/OR condition group.
class ConditionGroupResult {
  /// `"AND"` or `"OR"` — copied from the group's `operator` field.
  final String operator;

  final bool satisfied;

  /// Results for every individual condition inside this group.
  final List<ConditionResult> conditionResults;

  const ConditionGroupResult({
    required this.operator,
    required this.satisfied,
    required this.conditionResults,
  });

  /// Conditions that were not satisfied in this group.
  List<ConditionResult> get failedConditions =>
      conditionResults.where((r) => !r.satisfied).toList();
}

/// Outcome of evaluating one qualification route (e.g. `"SPM"`) within a
/// pathway.
class RouteResult {
  /// The qualification key this result belongs to (e.g. `"SPM"`, `"STPM"`).
  final String qualification;

  final bool satisfied;

  /// Results for every condition group inside the route.
  final List<ConditionGroupResult> groupResults;

  /// Whether the primary requirement check passed.
  ///
  /// The primary requirement covers three metadata fields that are now
  /// evaluated alongside [conditionGroups]:
  /// - `minimumGrade` + `minimumRelevantSubjects` — student must have at
  ///   least N subjects at the minimum grade in this qualification.
  /// - `minimumCgpa` — student's CGPA entry for this qualification (stored as
  ///   a synthetic `AcademicResultEntry` with `subject: "CGPA"`) must meet
  ///   the required floor.
  ///
  /// `true` when no primary requirement is configured (vacuously satisfied).
  final bool primaryRequirementSatisfied;

  const RouteResult({
    required this.qualification,
    required this.satisfied,
    required this.groupResults,
    required this.primaryRequirementSatisfied,
  });

  /// All failed conditions across every group in this route.
  List<ConditionResult> get failedConditions =>
      groupResults.expand((g) => g.failedConditions).toList();
}

/// Outcome of evaluating one [Course] admission pathway.
class PathwayResult {
  final String pathwayName;

  final bool satisfied;

  /// Route results, keyed by qualification, for every qualification route that
  /// had a matching entry in the student's results.
  ///
  /// Routes whose qualification key was not present in the student's supplied
  /// results map are omitted (they are not applicable to this student).
  final Map<String, RouteResult> routeResults;

  const PathwayResult({
    required this.pathwayName,
    required this.satisfied,
    required this.routeResults,
  });

  /// All failed conditions across every evaluated route in this pathway.
  List<ConditionResult> get failedConditions =>
      routeResults.values.expand((r) => r.failedConditions).toList();
}

/// Top-level result returned by [RecommendationEngine.evaluateCourse].
class CourseEvaluationResult {
  final Course course;

  /// `true` when the student satisfies at least one admission pathway.
  final bool eligible;

  /// The first pathway that was satisfied, or `null` when ineligible.
  final PathwayResult? matchedPathway;

  /// Results for every pathway in the course, in document order.
  final List<PathwayResult> pathwayResults;

  const CourseEvaluationResult({
    required this.course,
    required this.eligible,
    required this.matchedPathway,
    required this.pathwayResults,
  });

  /// When ineligible, returns the failed conditions from the pathway that came
  /// closest to being satisfied (fewest individual failures).
  ///
  /// This is intended for UI display so the student knows exactly what is
  /// missing.  Returns an empty list when [eligible] is `true` or when no
  /// applicable pathway was found for the student's qualification.
  List<ConditionResult> get failedConditions {
    if (eligible) return const [];

    // Only consider pathways where at least one route matched the student's
    // qualification — ignore pathways that simply had no applicable route.
    final applicable =
        pathwayResults.where((p) => p.routeResults.isNotEmpty).toList();
    if (applicable.isEmpty) return const [];

    final best = applicable.reduce((a, b) =>
        a.failedConditions.length <= b.failedConditions.length ? a : b);
    return best.failedConditions;
  }

  @override
  String toString() =>
      'CourseEvaluationResult('
      'course: "${course.code}", '
      'eligible: $eligible, '
      'matchedPathway: ${matchedPathway?.pathwayName}'
      ')';
}

// =============================================================================
// Engine
// =============================================================================

/// Pure-logic service that checks whether a student's academic results satisfy
/// the admission requirements of a [Course].
///
/// ## Inputs
///
/// [studentResults] is a map from qualification type to the list of subject–
/// grade entries for that qualification.  For an SPM student this would be:
///
/// ```dart
/// {
///   'SPM': [
///     AcademicResultEntry(subject: 'Mathematics',           grade: 'A'),
///     AcademicResultEntry(subject: 'Additional Mathematics', grade: 'B+'),
///     AcademicResultEntry(subject: 'English',               grade: 'C'),
///   ],
/// }
/// ```
///
/// A student who holds multiple qualifications can supply multiple keys:
///
/// ```dart
/// {
///   'SPM':  [...],
///   'STPM': [...],
/// }
/// ```
///
/// ## Evaluation tree
///
/// ```
/// evaluateCourse               OR  → eligible when ANY pathway passes
///   └─ evaluatePathway         AND → passes when ALL matched routes pass
///        └─ evaluateRoute      AND → passes when ALL condition groups pass
///             └─ evaluateConditionGroup
///               ├─ AND mode    AND → passes when ALL conditions pass
///               └─ OR  mode    OR  → passes when ANY condition passes
///                    └─ evaluateCondition
///                         └─ GradeScale.meetsRequirement
/// ```
///
/// Routes with no matching student qualification are silently skipped.
/// Routes that carry only a CGPA requirement (`conditionGroups` is empty) are
/// treated as vacuously satisfied — CGPA data is outside the scope of the
/// OCR-based grade engine.
class RecommendationEngine {
  const RecommendationEngine();

  // ---------------------------------------------------------------------------
  // evaluateCourse
  // ---------------------------------------------------------------------------

  /// Evaluates [course] against [studentResults] and returns a
  /// [CourseEvaluationResult].
  ///
  /// Iterates [Course.admissionPathways] and stops at the first satisfied
  /// pathway (OR semantics across pathways).
  CourseEvaluationResult evaluateCourse(
    Course course,
    Map<String, List<AcademicResultEntry>> studentResults,
  ) {
    final pathwayResults = course.admissionPathways
        .map((p) => evaluatePathway(p, studentResults))
        .toList();

    PathwayResult? matchedPathway;
    for (final result in pathwayResults) {
      if (result.satisfied) {
        matchedPathway = result;
        break;
      }
    }

    return CourseEvaluationResult(
      course: course,
      eligible: matchedPathway != null,
      matchedPathway: matchedPathway,
      pathwayResults: pathwayResults,
    );
  }

  // ---------------------------------------------------------------------------
  // evaluatePathway
  // ---------------------------------------------------------------------------

  /// Evaluates one admission pathway map from [Course.admissionPathways].
  ///
  /// Only qualification routes whose key exists in [studentResults] are
  /// evaluated.  The pathway is satisfied when every evaluated route is
  /// satisfied and at least one route was evaluated (AND semantics).
  ///
  /// If none of the route keys match the student's qualifications, the pathway
  /// is not applicable and [PathwayResult.satisfied] is `false`.
  PathwayResult evaluatePathway(
    Map<String, dynamic> pathway,
    Map<String, List<AcademicResultEntry>> studentResults,
  ) {
    final pathwayName =
        pathway['pathwayName'] as String? ?? 'Default Pathway';

    final rawRoutes = pathway['qualificationRoutes'];
    final routeMap = rawRoutes is Map
        ? Map<String, dynamic>.from(rawRoutes)
        : <String, dynamic>{};

    final routeResults = <String, RouteResult>{};
    for (final entry in routeMap.entries) {
      final qualification = entry.key as String;
      if (!studentResults.containsKey(qualification)) continue;

      final routeData = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : <String, dynamic>{};

      routeResults[qualification] = evaluateRoute(
        qualification,
        routeData,
        studentResults,
      );
    }

    final satisfied = routeResults.isNotEmpty &&
        routeResults.values.every((r) => r.satisfied);

    return PathwayResult(
      pathwayName: pathwayName,
      satisfied: satisfied,
      routeResults: routeResults,
    );
  }

  // ---------------------------------------------------------------------------
  // evaluateRoute
  // ---------------------------------------------------------------------------

  /// Evaluates one qualification route map for [qualification].
  ///
  /// Two checks must both pass for the route to be satisfied:
  ///
  /// 1. **Primary requirement** — `minimumGrade`, `minimumRelevantSubjects`,
  ///    and `minimumCgpa` (see [_evaluatePrimaryRequirement]).
  /// 2. **Condition groups** — all `conditionGroups` must pass (AND semantics).
  ///    An empty list is vacuously satisfied.
  RouteResult evaluateRoute(
    String qualification,
    Map<String, dynamic> route,
    Map<String, List<AcademicResultEntry>> studentResults,
  ) {
    final rawGroups = route['conditionGroups'];
    final groups = rawGroups is List
        ? rawGroups
            .whereType<Map>()
            .map((g) => Map<String, dynamic>.from(g))
            .toList()
        : <Map<String, dynamic>>[];

    final groupResults =
        groups.map((g) => evaluateConditionGroup(g, studentResults)).toList();

    final primarySatisfied =
        _evaluatePrimaryRequirement(qualification, route, studentResults);

    final conditionsSatisfied =
        groupResults.isEmpty || groupResults.every((g) => g.satisfied);

    return RouteResult(
      qualification: qualification,
      satisfied: primarySatisfied && conditionsSatisfied,
      groupResults: groupResults,
      primaryRequirementSatisfied: primarySatisfied,
    );
  }

  // ---------------------------------------------------------------------------
  // _evaluatePrimaryRequirement
  // ---------------------------------------------------------------------------

  /// Evaluates the three primary-requirement metadata fields for [qualification].
  ///
  /// ### minimumCgpa
  /// Looks for a synthetic entry `{ subject: "CGPA", grade: "<double>" }` in
  /// the student's results for this qualification.  When found, parses the
  /// grade string as a double and compares it against [minimumCgpa].
  /// When no CGPA entry is present the check is vacuously satisfied — the
  /// student simply has not provided CGPA data yet.
  ///
  /// ### minimumGrade + minimumRelevantSubjects
  /// Counts how many subjects in the student's results for this qualification
  /// meet [minimumGrade] (using [GradeScale.meetsRequirement]).  CGPA sentinel
  /// entries are excluded from this count.  The route passes when
  /// `qualifyingCount >= minimumRelevantSubjects`.
  ///
  /// When either field is `null` the corresponding check is skipped
  /// (vacuously satisfied).
  bool _evaluatePrimaryRequirement(
    String qualification,
    Map<String, dynamic> route,
    Map<String, List<AcademicResultEntry>> studentResults,
  ) {
    final minimumGrade = route['minimumGrade'] as String?;
    final minimumRelevantSubjects =
        route['minimumRelevantSubjects'] as int?;
    final minimumCgpa = (route['minimumCgpa'] as num?)?.toDouble();

    final qualResults = studentResults[qualification] ?? const [];

    // ── CGPA check ────────────────────────────────────────────────────────────
    if (minimumCgpa != null) {
      final cgpaEntries = qualResults.where(
        (e) => e.subject.trim().toLowerCase() == 'cgpa',
      );
      if (cgpaEntries.isNotEmpty) {
        final studentCgpa = double.tryParse(cgpaEntries.first.grade);
        if (studentCgpa == null || studentCgpa < minimumCgpa) return false;
      }
      // No CGPA entry present → cannot evaluate, treat as vacuously satisfied.
    }

    // ── Minimum grade × subject count check ───────────────────────────────────
    if (minimumGrade != null && minimumRelevantSubjects != null) {
      int qualifyingCount = 0;
      for (final entry in qualResults) {
        if (entry.subject.trim().toLowerCase() == 'cgpa') continue;
        if (GradeScale.meetsRequirement(
          requiredGrade: minimumGrade,
          studentGrade: entry.grade,
        )) {
          qualifyingCount++;
        }
      }
      if (qualifyingCount < minimumRelevantSubjects) return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // evaluateConditionGroup
  // ---------------------------------------------------------------------------

  /// Evaluates one condition group map.
  ///
  /// When `operator` is `"OR"`: at least one condition must be satisfied.
  /// When `operator` is `"AND"` (default): every condition must be satisfied.
  ConditionGroupResult evaluateConditionGroup(
    Map<String, dynamic> group,
    Map<String, List<AcademicResultEntry>> studentResults,
  ) {
    final operator =
        (group['operator'] as String? ?? 'AND').trim().toUpperCase();

    final rawConditions = group['conditions'];
    final conditions = rawConditions is List
        ? rawConditions
            .whereType<Map>()
            .map((c) => Map<String, dynamic>.from(c))
            .toList()
        : <Map<String, dynamic>>[];

    final conditionResults =
        conditions.map((c) => evaluateCondition(c, studentResults)).toList();

    final satisfied = operator == 'OR'
        ? conditionResults.any((r) => r.satisfied)
        : conditionResults.every((r) => r.satisfied);

    return ConditionGroupResult(
      operator: operator,
      satisfied: satisfied,
      conditionResults: conditionResults,
    );
  }

  // ---------------------------------------------------------------------------
  // evaluateCondition
  // ---------------------------------------------------------------------------

  /// Evaluates one condition entry against [studentResults].
  ///
  /// Looks up `condition["subject"]` inside
  /// `studentResults[condition["qualification"]]`.  Subject matching is
  /// case-insensitive and whitespace-tolerant.
  ///
  /// Returns `satisfied: false` (with `studentGrade: null`) when:
  /// - the qualification key is absent from [studentResults], or
  /// - the subject is not found in that qualification's result list.
  ///
  /// Grade comparison delegates to [GradeScale.meetsRequirement], which
  /// accepts both TARUMT keywords (`"Credit"`, `"Pass"`) and direct letter
  /// grades (`"C"`, `"B+"`, etc.).
  ConditionResult evaluateCondition(
    Map<String, dynamic> condition,
    Map<String, List<AcademicResultEntry>> studentResults,
  ) {
    final qualification = condition['qualification'] as String? ?? 'SPM';
    final subject = (condition['subject'] as String? ?? '').trim();
    final requiredGrade = condition['grade'] as String? ?? '';

    final resultsForQual = studentResults[qualification] ?? const [];

    // Case- and whitespace-insensitive subject lookup.
    final subjectLower = subject.toLowerCase();
    final matches = resultsForQual.where(
      (e) => e.subject.trim().toLowerCase() == subjectLower,
    );

    if (matches.isEmpty) {
      return ConditionResult(
        condition: condition,
        satisfied: false,
        studentGrade: null,
      );
    }

    final entry = matches.first;

    // meetsRequirement never throws — returns false for unrecognised grades.
    final satisfied = GradeScale.meetsRequirement(
      requiredGrade: requiredGrade,
      studentGrade: entry.grade,
    );

    return ConditionResult(
      condition: condition,
      satisfied: satisfied,
      studentGrade: entry.grade,
    );
  }
}
