import 'package:flutter/material.dart';

import '../models/scholarship.dart';

/// Read-only scholarship detail view for students.
class ScholarshipDetailScreen extends StatelessWidget {
  const ScholarshipDetailScreen({
    super.key,
    required this.scholarship,
  });

  final ScholarshipModel scholarship;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(scholarship.title),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            scholarship.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scholarship.category,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          _InfoSection(
            icon: Icons.percent,
            title: 'Waiver Percentage',
            content: scholarship.waiverLabel,
          ),
          const SizedBox(height: 12),
          if (scholarship.description.isNotEmpty) ...[
            _InfoSection(
              icon: Icons.info_outline,
              title: 'Description',
              content: scholarship.description,
            ),
            const SizedBox(height: 12),
          ],
          _InfoSection(
            icon: Icons.checklist_rtl,
            title: 'Eligibility Criteria',
            content: scholarship.eligibilityCriteria,
          ),
          const SizedBox(height: 12),
          _InfoSection(
            icon: Icons.school_outlined,
            title: 'Retention Criteria',
            content: scholarship.retentionCriteria,
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'Scholarship applications are not available yet. '
              'Eligible students are automatically considered upon admission '
              'according to TAR UMT Merit Scholarship terms.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
