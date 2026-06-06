import 'package:flutter/material.dart';

import '../models/academic_result_entry.dart';
import '../models/course_fit_result.dart';
import '../models/parsed_academic_result.dart';
import '../models/recommendation_explanation.dart';
import '../models/student_interest.dart';
import '../services/course_fit_matcher.dart';
import '../services/course_service.dart';
import '../services/interest_matcher.dart';
import '../services/recommendation_engine.dart';
import '../services/recommendation_explainer.dart';
import '../services/student_interest_service.dart';
import '../services/student_result_service.dart';
import '../services/student_session.dart';

// =============================================================================
// Private record type — pairs a ranked result with its explanation
// =============================================================================

typedef _CourseEntry = ({
  CourseFitResult fit,
  RecommendationExplanation explanation,
});

/// Displays the list of courses the student is eligible for, ranked by a
/// combined score of career interest alignment and academic subject strength.
/// Every card includes an expandable "Why this course?" panel.
///
/// ## Data flow
///
/// ```
/// userId
///   ├─ StudentResultService   ← academic grades
///   ├─ StudentInterestService ← RIASEC profile (concurrent)
///   └─ CourseService          ← course catalogue (concurrent)
///         │
///         ▼
///   RecommendationEngine      ← eligibility (untouched)
///         │  filter eligible
///         ▼
///   InterestMatcher           ← interest score (untouched)
///         │
///         ▼
///   CourseFitMatcher          ← academic-strength + overall score (untouched)
///         │
///         ▼
///   RecommendationExplainer   ← explanation data (read-only, no recalculation)
///         │
///         ▼  sort: overall DESC → academic DESC → interest DESC → name ASC
///   ListView of _CourseEligibilityCard (expandable)
/// ```
///
/// ### Ranking formula (unchanged from Sprint 5)
///
/// ```
/// overallMatchPercent = (interestMatchPercent × 0.5) + (academicStrengthPercent × 0.5)
/// ```
class RecommendationScreen extends StatefulWidget {
  final ParsedAcademicResult? parsedResult;
  final String? userId;

  const RecommendationScreen({super.key, this.parsedResult, this.userId});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final _courseService = CourseService();
  final _resultService = StudentResultService();
  final _interestService = StudentInterestService();
  final _engine = const RecommendationEngine();
  final _matcher = const InterestMatcher();
  final _fitMatcher = const CourseFitMatcher();
  final _explainer = const RecommendationExplainer();

  bool _isLoading = true;
  String? _error;

  /// Eligible courses ranked and paired with their explanations.
  List<_CourseEntry> _rankedResults = const [];

  bool _hasNoData = false;

  /// Controls whether Interest Match / Overall Match rows are visible on cards.
  bool _hasInterestProfile = false;

  @override
  void initState() {
    super.initState();
    _loadAndEvaluate();
  }

  Future<void> _loadAndEvaluate() async {
    final uid = widget.userId ?? StudentSession.currentStudentId;

    try {
      final coursesFuture = _courseService.getActiveCourses();
      final interestFuture = (uid.isNotEmpty && uid != 'guest_user')
          ? _interestService.getInterests(uid)
          : Future<StudentInterest?>.value(null);

      Map<String, List<AcademicResultEntry>>? engineInput;

      if (uid.isNotEmpty && uid != 'guest_user') {
        final record = await _resultService.getResults(uid);
        if (record != null) engineInput = record.toEngineInput();
      }

      if (engineInput == null &&
          widget.parsedResult != null &&
          widget.parsedResult!.results.isNotEmpty) {
        engineInput = {'SPM': widget.parsedResult!.results};
      }

      if (engineInput == null) {
        setState(() {
          _hasNoData = true;
          _isLoading = false;
        });
        return;
      }

      final spmEntries =
          engineInput['SPM'] ?? const <AcademicResultEntry>[];

      final courses = await coursesFuture;
      final studentInterest = await interestFuture;

      // Step 4: eligibility (RecommendationEngine — untouched)
      final eligible = courses
          .map((c) => _engine.evaluateCourse(c, engineInput!))
          .where((r) => r.eligible)
          .toList();

      // Step 5: interest match (InterestMatcher — untouched)
      final withInterest = eligible
          .map((r) => _matcher.wrap(r, studentInterest))
          .toList();

      // Step 6: academic-strength layer (CourseFitMatcher — untouched)
      final fitted = withInterest
          .map((r) => _fitMatcher.compute(r, spmEntries))
          .toList()
        ..sort((a, b) {
          final overall =
              b.overallMatchPercent.compareTo(a.overallMatchPercent);
          if (overall != 0) return overall;
          final academic =
              b.academicStrengthScore.compareTo(a.academicStrengthScore);
          if (academic != 0) return academic;
          final interest = b.interestScore.compareTo(a.interestScore);
          if (interest != 0) return interest;
          return a.course.name.compareTo(b.course.name);
        });

      // Step 7: build explanation for each ranked result (read-only)
      final ranked = fitted
          .map((fit) => (
                fit: fit,
                explanation:
                    _explainer.explain(fit, studentInterest, spmEntries),
              ))
          .toList();

      setState(() {
        _rankedResults = ranked;
        _hasInterestProfile =
            studentInterest != null && studentInterest.isComplete;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recommendations'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text(
              'Evaluating courses…',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _loadAndEvaluate();
        },
      );
    }

    if (_hasNoData) return const _NoResultsState();
    if (_rankedResults.isEmpty) return const _EmptyEligibilityState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudentSessionBanner(),
        _SummaryBanner(
          count: _rankedResults.length,
          hasInterestProfile: _hasInterestProfile,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _rankedResults.length,
            itemBuilder: (context, index) {
              final entry = _rankedResults[index];
              return _CourseEligibilityCard(
                fit: entry.fit,
                explanation: entry.explanation,
                showInterest: _hasInterestProfile,
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Eligibility card — expandable
// =============================================================================

class _CourseEligibilityCard extends StatefulWidget {
  final CourseFitResult fit;
  final RecommendationExplanation explanation;
  final bool showInterest;

  const _CourseEligibilityCard({
    required this.fit,
    required this.explanation,
    required this.showInterest,
  });

  @override
  State<_CourseEligibilityCard> createState() => _CourseEligibilityCardState();
}

class _CourseEligibilityCardState extends State<_CourseEligibilityCard> {
  bool _expanded = false;

  static Color _scoreColor(int percent) {
    if (percent >= 67) return const Color(0xFF2E7D32);
    if (percent >= 34) return const Color(0xFF1565C0);
    if (percent > 0) return const Color(0xFFE65100);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final fit = widget.fit;
    final course = fit.course;
    final matchedRoutes =
        fit.evaluation.matchedPathway?.routeResults.keys.join(' + ') ?? '—';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Faculty + level ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  course.faculty,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                _LevelBadge(level: course.level),
              ],
            ),
            const SizedBox(height: 8),

            // ── Course name ───────────────────────────────────────────────────
            Text(
              course.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),

            // ── Course code ───────────────────────────────────────────────────
            Text(
              'Code: ${course.code}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),

            // ── Eligibility ───────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                const Text(
                  'Eligible',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                Icon(Icons.school_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Via $matchedRoutes',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            // ── Interest Match (profile required) ────────────────────────────
            if (widget.showInterest) ...[
              const SizedBox(height: 8),
              _ScoreRow(
                icon: Icons.favorite_border,
                label: 'Interest Match',
                percent: fit.interestMatchPercent,
                color: _scoreColor(fit.interestMatchPercent),
              ),
            ],

            // ── Academic Fit (always) ─────────────────────────────────────────
            const SizedBox(height: 8),
            _ScoreRow(
              icon: Icons.menu_book_outlined,
              label: 'Academic Fit',
              percent: fit.academicStrengthPercent,
              color: _scoreColor(fit.academicStrengthPercent),
            ),

            // ── Overall Match (profile required) ─────────────────────────────
            if (widget.showInterest) ...[
              const SizedBox(height: 8),
              _ScoreRow(
                icon: Icons.stars_outlined,
                label: 'Overall Match',
                percent: fit.overallMatchPercent,
                color: _scoreColor(fit.overallMatchPercent),
                bold: true,
              ),
            ],

            // ── Expand / collapse toggle ──────────────────────────────────────
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 15,
                      color: Colors.blueAccent.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Why this course is recommended',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent.shade700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.blueAccent.shade700,
                    ),
                  ],
                ),
              ),
            ),

            // ── Explanation panel (animated) ──────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? _ExplanationPanel(explanation: widget.explanation)
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/courseDetail',
                  arguments: course,
                ),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('View Details & Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Explanation panel
// =============================================================================

class _ExplanationPanel extends StatelessWidget {
  final RecommendationExplanation explanation;

  const _ExplanationPanel({required this.explanation});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Divider(height: 1, color: Color(0xFFE8F0FE)),
        const SizedBox(height: 14),

        // ── Eligibility ─────────────────────────────────────────────────────
        _ExplainSection(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF2E7D32),
          title: 'Eligibility',
          child: _InfoRow(
            leading: const Icon(Icons.circle, size: 6, color: Color(0xFF2E7D32)),
            text: 'Eligible via ${explanation.eligibleVia} pathway',
          ),
        ),
        const SizedBox(height: 14),

        // ── Interest Match (only when profile exists) ────────────────────────
        if (explanation.hasInterestProfile) ...[
          _ExplainSection(
            icon: Icons.favorite_outline,
            iconColor: const Color(0xFF1565C0),
            title: 'Interest Match',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelRow(
                  label: 'Your interests',
                  value: explanation.studentInterestNames
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value}')
                      .join('   '),
                ),
                const SizedBox(height: 4),
                _LabelRow(
                  label: 'Course areas',
                  value: explanation.courseInterestTags.join('   ·   '),
                ),
                const SizedBox(height: 4),
                _LabelRow(
                  label: 'Matched',
                  value: explanation.matchedInterestTags.isEmpty
                      ? 'None'
                      : explanation.matchedInterestTags.join('   ·   '),
                  valueColor: explanation.matchedInterestTags.isEmpty
                      ? Colors.grey
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 8),
                _ScoreLine(
                  label: 'Interest Match',
                  percent: explanation.interestMatchPercent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Academic Strength ────────────────────────────────────────────────
        _ExplainSection(
          icon: Icons.menu_book_outlined,
          iconColor: const Color(0xFF6A1B9A),
          title: 'Academic Strength',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (explanation.subjectFits.isEmpty)
                Text(
                  'No subject criteria defined for this course.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                )
              else
                ...explanation.subjectFits.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          s.found
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: s.found
                              ? const Color(0xFF2E7D32)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.subject,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        Text(
                          s.found ? s.grade! : '—',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: s.found
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${s.weight}/5)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _ScoreLine(
                label: 'Academic Fit',
                percent: explanation.academicFitPercent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Final Score ──────────────────────────────────────────────────────
        _ExplainSection(
          icon: Icons.stars_outlined,
          iconColor: const Color(0xFFE65100),
          title: 'Final Score',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (explanation.hasInterestProfile) ...[
                _FormulaRow(
                  label: 'Interest Match',
                  percent: explanation.interestMatchPercent,
                  weight: '× 50%',
                ),
                const SizedBox(height: 2),
                _FormulaRow(
                  label: 'Academic Fit',
                  percent: explanation.academicFitPercent,
                  weight: '× 50%',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                ),
              ],
              _ScoreLine(
                label: 'Overall Match',
                percent: explanation.overallMatchPercent,
                bold: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// =============================================================================
// Explanation sub-widgets
// =============================================================================

/// Section header with icon, title, and indented child content.
class _ExplainSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _ExplainSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: iconColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: child,
        ),
      ],
    );
  }
}

/// A label + colon + coloured value row used inside explanation sections.
class _LabelRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _LabelRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

/// A bullet row for plain text notes.
class _InfoRow extends StatelessWidget {
  final Widget leading;
  final String text;

  const _InfoRow({required this.leading, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

/// A "Label  XX%" line used to close each explanation section.
class _ScoreLine extends StatelessWidget {
  final String label;
  final int percent;
  final bool bold;

  const _ScoreLine({
    required this.label,
    required this.percent,
    this.bold = false,
  });

  Color get _color {
    if (percent >= 67) return const Color(0xFF2E7D32);
    if (percent >= 34) return const Color(0xFF1565C0);
    if (percent > 0) return const Color(0xFFE65100);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _color.withOpacity(0.4)),
          ),
          child: Text(
            '$percent%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: _color,
            ),
          ),
        ),
      ],
    );
  }
}

/// One row in the formula breakdown: "Interest Match   50%  × 50%".
class _FormulaRow extends StatelessWidget {
  final String label;
  final int percent;
  final String weight;

  const _FormulaRow({
    required this.label,
    required this.percent,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const Spacer(),
        Text(
          '$percent%',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
        const SizedBox(width: 6),
        Text(
          weight,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared metric row + badge (existing Sprint-5 widgets — unchanged)
// =============================================================================

class _ScoreRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int percent;
  final Color color;
  final bool bold;

  const _ScoreRow({
    required this.icon,
    required this.label,
    required this.percent,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final weight = bold ? FontWeight.w700 : FontWeight.w600;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: weight, color: color),
        ),
        const Spacer(),
        _PercentBadge(percent: percent, color: color, bold: bold),
      ],
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final int percent;
  final Color color;
  final bool bold;

  const _PercentBadge({
    required this.percent,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// =============================================================================
// Level badge
// =============================================================================

class _LevelBadge extends StatelessWidget {
  final String level;

  const _LevelBadge({required this.level});

  static Color _badgeColor(String level) {
    switch (level.toLowerCase()) {
      case 'bachelor':
        return const Color(0xFF1565C0);
      case 'diploma':
        return const Color(0xFF6A1B9A);
      case 'foundation':
        return const Color(0xFF00695C);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _badgeColor(level).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _badgeColor(level).withOpacity(0.4)),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _badgeColor(level),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// =============================================================================
// Summary banner
// =============================================================================

class _SummaryBanner extends StatelessWidget {
  final int count;
  final bool hasInterestProfile;

  const _SummaryBanner({
    required this.count,
    required this.hasInterestProfile,
  });

  @override
  Widget build(BuildContext context) {
    final courseWord = count == 1 ? 'course' : 'courses';
    final bodyText = hasInterestProfile
        ? 'You are eligible for $count $courseWord. '
            'Ranked by career interests and academic strengths.'
        : 'You are eligible for $count $courseWord. '
            'Ranked by academic strengths.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined,
              size: 18, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bodyText,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Empty / error states (unchanged)
// =============================================================================

class _EmptyEligibilityState extends StatelessWidget {
  const _EmptyEligibilityState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No eligible courses found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Your current results do not meet the entry requirements '
              'for any active course. Please consult a counsellor for guidance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No results uploaded yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Please scan your result certificate first so the engine '
              'can evaluate your eligibility.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
