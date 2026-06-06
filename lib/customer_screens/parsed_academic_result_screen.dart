import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academic_result_entry.dart';
import '../models/parsed_academic_result.dart';
import '../models/student_info.dart';
import '../services/student_result_service.dart';
import '../services/student_session.dart';
import 'recommendation_screen.dart';

/// Displays the output of [AcademicResultParser]:
///   • Student information (name, IC, candidate ID)
///   • Subject–grade table (grades shown as coloured badges)
///   • Collapsible JSON preview for debugging
///
/// Ministry headers, school names, QR content, certificate serials, footer
/// text, and grade descriptions are never passed to this screen — they are
/// filtered out by the parser before [ParsedAcademicResult] is constructed.
class ParsedAcademicResultScreen extends StatefulWidget {
  final ParsedAcademicResult parsedResult;

  const ParsedAcademicResultScreen({super.key, required this.parsedResult});

  @override
  State<ParsedAcademicResultScreen> createState() =>
      _ParsedAcademicResultScreenState();
}

class _ParsedAcademicResultScreenState
    extends State<ParsedAcademicResultScreen> {
  bool _jsonExpanded = false;
  bool _isSaving = false;

  final _service = StudentResultService();

  String get _prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(widget.parsedResult.toJson());
  }

  void _copyJson() {
    Clipboard.setData(ClipboardData(text: _prettyJson));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("JSON copied to clipboard")),
    );
  }

  Future<void> _getRecommendations() async {
    final results = widget.parsedResult.results;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No academic results to process.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Use the active development session ID so all screens consistently
      // target the same Firestore document regardless of OCR accuracy.
      // Replace with Firebase Auth UID before production release.
      final userId = StudentSession.currentStudentId;

      await _service.saveResults(
        userId: userId,
        qualificationType: 'SPM',
        results: results,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecommendationScreen(
            parsedResult: widget.parsedResult,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save results: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Academic Result"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Copy JSON",
            icon: const Icon(Icons.data_object),
            onPressed: _copyJson,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StudentSessionBanner(),
                const SizedBox(height: 12),
                _StudentInfoCard(info: widget.parsedResult.studentInfo),
                const SizedBox(height: 16),
                _ResultsCard(results: widget.parsedResult.results),
                const SizedBox(height: 16),
                _JsonPreviewCard(
                  prettyJson: _prettyJson,
                  expanded: _jsonExpanded,
                  onToggle: () =>
                      setState(() => _jsonExpanded = !_jsonExpanded),
                  onCopy: _copyJson,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isSaving ||
                          widget.parsedResult.results.isEmpty
                      ? null
                      : _getRecommendations,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.recommend),
                  label: Text(_isSaving ? 'Saving...' : 'Get Recommendations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.blueAccent.withOpacity(0.5),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Back to Upload"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Student Information Card ──────────────────────────────────────────────────

class _StudentInfoCard extends StatelessWidget {
  final StudentInfo? info;

  const _StudentInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.person_outline,
      title: "Student Information",
      child: Column(
        children: [
          _InfoRow(label: "Name", value: info?.name),
          const _Divider(),
          _InfoRow(label: "IC Number", value: info?.ic),
          const _Divider(),
          _InfoRow(label: "Candidate ID", value: info?.candidateId),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final bool detected = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detected ? value! : "Not Detected",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: detected ? Colors.black87 : Colors.red.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Academic Results Card ─────────────────────────────────────────────────────

class _ResultsCard extends StatelessWidget {
  final List<AcademicResultEntry> results;

  const _ResultsCard({required this.results});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.school_outlined,
      title: "Academic Results",
      trailing: results.isNotEmpty
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${results.length} subject${results.length == 1 ? '' : 's'}",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      child: results.isEmpty
          ? _EmptyResultsRow()
          : Column(
              children: results.asMap().entries.map((e) {
                return _ResultRow(
                  entry: e.value,
                  isLast: e.key == results.length - 1,
                );
              }).toList(),
            ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final AcademicResultEntry entry;
  final bool isLast;

  const _ResultRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _GradeBadge(grade: entry.grade),
            ],
          ),
        ),
        if (!isLast) const _Divider(),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final String grade;

  const _GradeBadge({required this.grade});

  static Color _badgeColor(String grade) {
    if (grade.isEmpty) return Colors.grey;
    switch (grade[0].toUpperCase()) {
      case 'A':
        return const Color(0xFF2E7D32); // dark green
      case 'B':
        return const Color(0xFF1565C0); // dark blue
      case 'C':
        return const Color(0xFFE65100); // deep orange
      case 'D':
        return const Color(0xFFF57F17); // amber
      default:
        return const Color(0xFFC62828); // dark red (E, G)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _badgeColor(grade),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        grade,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyResultsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          "No results detected",
          style: TextStyle(color: Colors.red.shade300, fontSize: 14),
        ),
      ),
    );
  }
}

// ── JSON Preview Card ─────────────────────────────────────────────────────────

class _JsonPreviewCard extends StatelessWidget {
  final String prettyJson;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  const _JsonPreviewCard({
    required this.prettyJson,
    required this.expanded,
    required this.onToggle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row — tappable toggle
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.data_object,
                      size: 18, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text(
                    "Debug: Raw JSON",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FF),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      prettyJson,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF263238),
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                // Copy button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.copy,
                            size: 16, color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared layout primitives ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // Section body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F0F0));
  }
}
