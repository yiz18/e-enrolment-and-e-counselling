import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/riasec_questions.dart';
import '../services/riasec_prediction_service.dart';

// =============================================================================
// Constants
// =============================================================================

const int _kSectionCount = 6;
const int _kQuestionsPerSection = 8;
const int _kTotalQuestions = _kSectionCount * _kQuestionsPerSection; // 48

// =============================================================================
// RiasecQuestionnaireScreen
// =============================================================================

/// Collects all 48 RIASEC questionnaire responses (1–5 Likert scale) across
/// 6 sections via a [PageView], POSTs them to the FastAPI `/predict` endpoint
/// via [RiasecPredictionService], and pops a result map on success.
///
/// ## Navigation — success
/// ```dart
/// final result = await Navigator.pushNamed(context, '/riasec-questionnaire');
/// // result == { 'top3Codes': ['I', 'E', 'S'] }
/// ```
///
/// ## Navigation — user exits or API fails without retry
/// The route pops with `null`.
///
/// The caller ([InterestProfileScreen]) checks for the `top3Codes` key and
/// saves the codes to Firestore via [StudentInterestService].
class RiasecQuestionnaireScreen extends StatefulWidget {
  const RiasecQuestionnaireScreen({super.key});

  @override
  State<RiasecQuestionnaireScreen> createState() =>
      _RiasecQuestionnaireScreenState();
}

class _RiasecQuestionnaireScreenState
    extends State<RiasecQuestionnaireScreen> {
  final PageController _pageController = PageController();
  final _predictionService = RiasecPredictionService();

  /// _responses[sectionIndex][questionIndex] = 1–5, or null if unanswered.
  final List<List<int?>> _responses = List.generate(
    _kSectionCount,
    (_) => List.filled(_kQuestionsPerSection, null),
  );

  int _currentSection = 0;

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  int get _totalAnswered => _responses.fold(
        0,
        (sum, section) => sum + section.where((v) => v != null).length,
      );

  bool _isSectionComplete(int section) =>
      _responses[section].every((v) => v != null);

  bool get _allComplete => _totalAnswered == _kTotalQuestions;

  RiasecSection get _currentDef => kRiasecSections[_currentSection];

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  void _onAnswer(int sectionIndex, int questionIndex, int value) {
    setState(() {
      _responses[sectionIndex][questionIndex] = value;
    });
  }

  void _goNext() {
    if (!_isSectionComplete(_currentSection)) {
      _showValidationSnack();
      return;
    }
    if (_currentSection < _kSectionCount - 1) {
      setState(() => _currentSection++);
      _pageController.animateToPage(
        _currentSection,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit(); // async — fire-and-forget intentionally; errors handled internally
    }
  }

  void _goPrevious() {
    if (_currentSection == 0) return;
    setState(() => _currentSection--);
    _pageController.animateToPage(
      _currentSection,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _showValidationSnack() {
    final unanswered = _responses[_currentSection].where((v) => v == null).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please answer all $unanswered remaining '
          '${unanswered == 1 ? 'question' : 'questions'} in this section.',
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_allComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all sections before submitting.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Build API-compatible payload: { "R1": 3, "R2": 4, ..., "C8": 2 }
    final Map<String, int> payload = {};
    for (int s = 0; s < _kSectionCount; s++) {
      for (int q = 0; q < _kQuestionsPerSection; q++) {
        payload[kRiasecSections[s].fieldName(q)] = _responses[s][q]!;
      }
    }

    // Show loading dialog while awaiting prediction.
    if (!mounted) return;
    _showLoadingDialog();

    try {
      final top3Codes = await _predictionService.predict(payload);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog

      // Return top3Codes to the caller (InterestProfileScreen).
      Navigator.pop(context, {'top3Codes': top3Codes});
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      _showErrorDialog(e);
    }
  }

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Analysing your responses…',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(Object error) {
    final message = switch (error) {
      AppConfigException(:final message) =>
        'The prediction service is not configured.\n\n$message',
      PredictionApiException(:final statusCode, :final body) =>
        'The server returned an error (HTTP $statusCode).\n\n$body',
      PredictionParseException(:final message) =>
        'The server response was unexpected.\n\n$message',
      _ => 'An unexpected error occurred:\n\n$error',
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Prediction Failed'),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submit(); // retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Assessment?'),
        content: const Text(
          'Your progress will not be saved. '
          'Are you sure you want to go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progress = _totalAnswered / _kTotalQuestions;
    final sectionColor = _currentDef.color;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(sectionColor),
        body: Column(
          children: [
            // ── Overall progress bar ───────────────────────────────────────
            _ProgressHeader(
              progress: progress,
              answered: _totalAnswered,
              total: _kTotalQuestions,
              color: sectionColor,
            ),

            // ── Section pages ──────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _kSectionCount,
                itemBuilder: (context, sectionIndex) => _SectionPage(
                  sectionIndex: sectionIndex,
                  section: kRiasecSections[sectionIndex],
                  responses: _responses[sectionIndex],
                  onAnswer: (qIndex, value) =>
                      _onAnswer(sectionIndex, qIndex, value),
                ),
              ),
            ),

            // ── Bottom navigation bar ──────────────────────────────────────
            _BottomNav(
              currentSection: _currentSection,
              totalSections: _kSectionCount,
              sectionColor: sectionColor,
              isSectionComplete: _isSectionComplete(_currentSection),
              onPrevious: _currentSection > 0 ? _goPrevious : null,
              onNext: _goNext,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(Color sectionColor) {
    return AppBar(
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _confirmExit,
        tooltip: 'Exit assessment',
      ),
      title: const Text(
        'RIASEC Assessment',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              'Section ${_currentSection + 1} / $_kSectionCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// =============================================================================
// _ProgressHeader
// =============================================================================

class _ProgressHeader extends StatelessWidget {
  final double progress;
  final int answered;
  final int total;
  final Color color;

  const _ProgressHeader({
    required this.progress,
    required this.answered,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$answered of $total questions answered',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SectionPage
// =============================================================================

class _SectionPage extends StatelessWidget {
  final int sectionIndex;
  final RiasecSection section;
  final List<int?> responses;
  final void Function(int questionIndex, int value) onAnswer;

  const _SectionPage({
    required this.sectionIndex,
    required this.section,
    required this.responses,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Section header card ──────────────────────────────────────────────
        _SectionHeader(section: section),
        const SizedBox(height: 16),

        // ── Likert legend (shown once per section) ───────────────────────────
        const _LikertLegend(),
        const SizedBox(height: 12),

        // ── 8 question cards ─────────────────────────────────────────────────
        for (int i = 0; i < _kQuestionsPerSection; i++) ...[
          _QuestionCard(
            number: i + 1,
            text: section.questions[i],
            selectedValue: responses[i],
            sectionColor: section.color,
            onSelected: (value) => onAnswer(i, value),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// =============================================================================
// _SectionHeader
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final RiasecSection section;

  const _SectionHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: section.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: section.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: section.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: section.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        section.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      section.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: section.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  section.tagline,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _LikertLegend
// =============================================================================

class _LikertLegend extends StatelessWidget {
  const _LikertLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '1 = Dislike',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            '3 = Neutral',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            '5 = Like',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _QuestionCard
// =============================================================================

class _QuestionCard extends StatelessWidget {
  final int number;
  final String text;
  final int? selectedValue;
  final Color sectionColor;
  final void Function(int value) onSelected;

  const _QuestionCard({
    required this.number,
    required this.text,
    required this.selectedValue,
    required this.sectionColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final answered = selectedValue != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answered
              ? sectionColor.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: answered ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Question text ─────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Number badge
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: answered
                        ? sectionColor
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: answered
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Likert buttons 1–5 ────────────────────────────────────────
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;
                final isSelected = selectedValue == value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 4 ? 4 : 0),
                    child: _LikertButton(
                      value: value,
                      label: kLikertLabels[i],
                      isSelected: isSelected,
                      color: sectionColor,
                      onTap: () => onSelected(value),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _LikertButton
// =============================================================================

class _LikertButton extends StatelessWidget {
  final int value;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _LikertButton({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.2,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey.shade500,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _BottomNav
// =============================================================================

class _BottomNav extends StatelessWidget {
  final int currentSection;
  final int totalSections;
  final Color sectionColor;
  final bool isSectionComplete;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  const _BottomNav({
    required this.currentSection,
    required this.totalSections,
    required this.sectionColor,
    required this.isSectionComplete,
    required this.onPrevious,
    required this.onNext,
  });

  bool get _isLastSection => currentSection == totalSections - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // ── Previous button ──────────────────────────────────────────────
          SizedBox(
            width: 100,
            child: onPrevious != null
                ? OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Section dots ─────────────────────────────────────────────────
          Expanded(
            child: _SectionDots(
              currentSection: currentSection,
              totalSections: totalSections,
              sectionColor: sectionColor,
            ),
          ),

          // ── Next / Submit button ──────────────────────────────────────────
          SizedBox(
            width: 100,
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: Icon(
                _isLastSection ? Icons.check_circle_outline : Icons.arrow_forward_ios,
                size: 15,
              ),
              label: Text(_isLastSection ? 'Submit' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSectionComplete ? sectionColor : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: isSectionComplete ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SectionDots
// =============================================================================

class _SectionDots extends StatelessWidget {
  final int currentSection;
  final int totalSections;
  final Color sectionColor;

  const _SectionDots({
    required this.currentSection,
    required this.totalSections,
    required this.sectionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSections, (i) {
        final isActive = i == currentSection;
        final isPast = i < currentSection;
        final dotColor = isPast
            ? kRiasecSections[i].color
            : isActive
                ? sectionColor
                : Colors.grey.shade300;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: isPast
              ? null
              : null,
        );
      }),
    );
  }
}
