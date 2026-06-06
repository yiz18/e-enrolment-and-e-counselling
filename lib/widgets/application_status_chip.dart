import 'package:flutter/material.dart';

import '../models/application.dart';

/// Coloured status badge for course application states.
///
/// Pending → Orange, Approved → Green, Rejected → Red.
class ApplicationStatusChip extends StatelessWidget {
  final ApplicationStatus status;

  const ApplicationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.firestoreValue,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static Color _colorForStatus(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.approved:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
    }
  }
}
