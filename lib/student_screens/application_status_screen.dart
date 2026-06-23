import 'package:flutter/material.dart';

import '../models/application.dart';
import '../widgets/application_status_chip.dart';

/// Detailed application review screen for a single course application.
class ApplicationStatusScreen extends StatelessWidget {
  final ApplicationModel application;

  const ApplicationStatusScreen({
    super.key,
    required this.application,
  });

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reviewedAt = application.reviewedAt;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Application Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.courseName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Course Code: ${application.courseCode}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ApplicationStatusChip(status: application.status),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Applied Date',
                      value: _formatDate(application.appliedAt.toLocal()),
                    ),
                    if (reviewedAt != null) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.fact_check_outlined,
                        label: 'Reviewed Date',
                        value: _formatDate(reviewedAt.toLocal()),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Admin Remark',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        application.displayRemark,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (application.reviewedBy != null &&
                        application.reviewedBy!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Reviewed By',
                        value: application.reviewedBy!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
