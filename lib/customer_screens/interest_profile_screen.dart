import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/student_interest.dart';
import '../services/student_interest_service.dart';
import '../services/student_session.dart';

// =============================================================================
// RIASEC option descriptors
// =============================================================================

class _RiasecOption {
  final String code;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _RiasecOption({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<_RiasecOption> _kOptions = [
  _RiasecOption(
    code: 'R',
    name: 'Realistic',
    description: 'Work with tools, machines, or nature',
    icon: Icons.build_outlined,
    color: Color(0xFF546E7A),
  ),
  _RiasecOption(
    code: 'I',
    name: 'Investigative',
    description: 'Explore ideas and solve problems',
    icon: Icons.science_outlined,
    color: Color(0xFF3949AB),
  ),
  _RiasecOption(
    code: 'A',
    name: 'Artistic',
    description: 'Create and express through arts',
    icon: Icons.palette_outlined,
    color: Color(0xFF8E24AA),
  ),
  _RiasecOption(
    code: 'S',
    name: 'Social',
    description: 'Help, teach, and support others',
    icon: Icons.people_outline,
    color: Color(0xFF388E3C),
  ),
  _RiasecOption(
    code: 'E',
    name: 'Enterprising',
    description: 'Lead, persuade, and manage',
    icon: Icons.trending_up,
    color: Color(0xFFEF6C00),
  ),
  _RiasecOption(
    code: 'C',
    name: 'Conventional',
    description: 'Organise, plan, and follow systems',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF00796B),
  ),
];

const String _kOnetUrl = 'https://www.mynextmove.org/explore/ip';

/// Circled digit labels for the three rank positions.
const List<String> _kRankLabels = ['①', '②', '③'];

// =============================================================================
// Screen
// =============================================================================

/// Allows the student to record their top 3 RIASEC interest areas after
/// completing the external O*NET Interest Profiler.
///
/// Selection order is significant — the first tapped code becomes rank 1
/// (dominant interest).  Deselecting any code shifts higher-ranked codes
/// down, preserving relative order.
///
/// Saved to Firestore at `studentInterests/{userId}` via
/// [StudentInterestService.saveInterests].
class InterestProfileScreen extends StatefulWidget {
  const InterestProfileScreen({super.key});

  @override
  State<InterestProfileScreen> createState() => _InterestProfileScreenState();
}

class _InterestProfileScreenState extends State<InterestProfileScreen> {
  final _service = StudentInterestService();

  /// Ordered selection: index 0 = rank 1 (dominant interest).
  /// Maximum length: [kRequiredRiasecCount] (3).
  List<String> _selectedCodes = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  // ---------------------------------------------------------------------------
  // Data operations
  // ---------------------------------------------------------------------------

  Future<void> _loadExisting() async {
    try {
      final record =
          await _service.getInterests(StudentSession.currentStudentId);
      if (mounted && record != null && record.riasecCodes.isNotEmpty) {
        setState(() {
          _selectedCodes = List<String>.from(record.riasecCodes);
        });
      }
    } catch (_) {
      // Non-fatal — student simply starts with an empty selection.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedCodes.length != kRequiredRiasecCount) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveInterests(
        StudentSession.currentStudentId,
        List<String>.from(_selectedCodes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Interests saved: ${_selectedCodes.join(' › ')}',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Interaction handlers
  // ---------------------------------------------------------------------------

  void _onCardTap(String code) {
    setState(() {
      if (_selectedCodes.contains(code)) {
        // Deselect: codes with higher rank shift down automatically because
        // their list positions are unchanged after remove().
        _selectedCodes.remove(code);
      } else if (_selectedCodes.length < kRequiredRiasecCount) {
        _selectedCodes.add(code);
      } else {
        // Already at maximum — prompt instead of silently doing nothing.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deselect one interest first.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// Launches the AI RIASEC questionnaire, awaits the result, saves interests
  /// to Firestore, and refreshes the selected card state.
  Future<void> _launchAiAssessment() async {
    final result = await Navigator.pushNamed(
      context,
      '/riasec-questionnaire',
    );

    if (!mounted) return;

    // Questionnaire returns: { 'top3Codes': ['I', 'E', 'S'] }
    if (result is! Map || !result.containsKey('top3Codes')) return;

    final raw = result['top3Codes'];
    if (raw is! List || raw.length != 3) return;

    final top3 = raw.whereType<String>().toList();
    if (top3.length != 3) return;

    // Persist to Firestore.
    setState(() => _isSaving = true);
    try {
      await _service.saveInterests(
        StudentSession.currentStudentId,
        top3,
      );
      if (!mounted) return;

      // Reflect prediction result in the card grid immediately.
      setState(() => _selectedCodes = top3);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI predicted your profile: ${top3.join(' › ')}',
          ),
          backgroundColor: const Color(0xFF6A1B9A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save AI prediction: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openOnet() async {
    final uri = Uri.parse(_kOnetUrl);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open browser.\nVisit: $_kOnetUrl',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching browser: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Career Interest Profile'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : Column(
              children: [
                const StudentSessionBanner(),
                Expanded(child: _buildScrollBody()),
              ],
            ),
    );
  }

  Widget _buildScrollBody() {
    final canSave = _selectedCodes.length == kRequiredRiasecCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── AI RIASEC Assessment card ──────────────────────────────────────
          _AiRiasecCard(onTake: _launchAiAssessment),
          const SizedBox(height: 16),

          // ── OR divider ─────────────────────────────────────────────────────
          const _OrDivider(),
          const SizedBox(height: 16),

          // ── O*NET intro + link ─────────────────────────────────────────────
          _OnetCard(onOpen: _openOnet),
          const SizedBox(height: 24),

          // ── Section heading + counter ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'My Top 3 Interest Areas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              _SelectionCounter(selected: _selectedCodes.length),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap up to 3 areas that match your assessment result. '
            'First tapped = highest priority.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // ── 2-column RIASEC grid ───────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _kOptions.length,
            itemBuilder: (context, i) {
              final opt = _kOptions[i];
              final rank = _selectedCodes.indexOf(opt.code); // -1 = unselected
              return _RiasecCard(
                option: opt,
                rank: rank,
                onTap: () => _onCardTap(opt.code),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Rank summary (visible only when ≥1 selected) ──────────────────
          _RankSummaryRow(selectedCodes: _selectedCodes),
          if (_selectedCodes.isNotEmpty) const SizedBox(height: 24),
          if (_selectedCodes.isEmpty) const SizedBox(height: 8),

          // ── Save button ────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: (canSave && !_isSaving) ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving…' : 'Save My Interests'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.blueAccent.withOpacity(0.35),
              disabledForegroundColor: Colors.white60,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // ── Helper text when save is disabled ─────────────────────────────
          if (!canSave) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Select ${kRequiredRiasecCount - _selectedCodes.length} more '
                '${(kRequiredRiasecCount - _selectedCodes.length) == 1 ? 'area' : 'areas'} to enable save',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],

          // ── Clear selection ────────────────────────────────────────────────
          if (_selectedCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _selectedCodes.clear()),
                icon: const Icon(Icons.clear, size: 15),
                label: const Text('Clear selection'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// _OnetCard
// =============================================================================

class _OnetCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _OnetCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Colors.blueAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Discover Your Interest Type',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Take the free O*NET Interest Profiler to identify your '
            'Holland Code (e.g. I–E–A). Then select your top 3 codes below.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open O*NET Interest Profiler'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _AiRiasecCard
// =============================================================================

class _AiRiasecCard extends StatelessWidget {
  final VoidCallback onTake;

  const _AiRiasecCard({required this.onTake});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: Colors.deepPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI RIASEC Assessment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Complete a 48-question assessment and let the AI model predict '
            'your Holland Code profile.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Estimated time: 3 minutes',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTake,
              icon: const Icon(Icons.play_arrow_outlined, size: 18),
              label: const Text('Take AI Assessment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _OrDivider
// =============================================================================

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }
}

// =============================================================================
// _SelectionCounter
// =============================================================================

class _SelectionCounter extends StatelessWidget {
  final int selected;

  const _SelectionCounter({required this.selected});

  @override
  Widget build(BuildContext context) {
    final done = selected == kRequiredRiasecCount;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF2E7D32).withOpacity(0.1)
            : Colors.blueAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$selected / $kRequiredRiasecCount',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: done ? const Color(0xFF2E7D32) : Colors.blueAccent,
        ),
      ),
    );
  }
}

// =============================================================================
// _RiasecCard
// =============================================================================

class _RiasecCard extends StatelessWidget {
  final _RiasecOption option;

  /// List index of this card's code in the selection (0-based).
  /// `-1` means not selected.
  final int rank;

  final VoidCallback onTap;

  const _RiasecCard({
    required this.option,
    required this.rank,
    required this.onTap,
  });

  bool get _selected => rank >= 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _selected ? option.color.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selected ? option.color : Colors.grey.shade300,
            width: _selected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_selected ? 0.08 : 0.04),
              blurRadius: _selected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Card body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 30, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    option.icon,
                    size: 26,
                    color: _selected ? option.color : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    option.code,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _selected ? option.color : Colors.grey.shade400,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          _selected ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ── Rank badge (top-right, visible when selected) ──────────────
            if (_selected)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _kRankLabels[rank],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _RankSummaryRow
// =============================================================================

/// Horizontal strip that shows the selected codes in priority order with
/// arrow separators.  Hidden when nothing is selected.
class _RankSummaryRow extends StatelessWidget {
  final List<String> selectedCodes;

  const _RankSummaryRow({required this.selectedCodes});

  _RiasecOption _opt(String code) =>
      _kOptions.firstWhere((o) => o.code == code);

  @override
  Widget build(BuildContext context) {
    if (selectedCodes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your selection — in priority order',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < selectedCodes.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                ],
                _RankChip(option: _opt(selectedCodes[i]), rank: i + 1),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _RankChip
// =============================================================================

class _RankChip extends StatelessWidget {
  final _RiasecOption option;
  final int rank; // 1-based

  const _RankChip({required this.option, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: option.color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: option.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _kRankLabels[rank - 1],
            style: TextStyle(
              fontSize: 13,
              color: option.color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            option.code,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: option.color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            option.name,
            style: TextStyle(
              fontSize: 12,
              color: option.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
