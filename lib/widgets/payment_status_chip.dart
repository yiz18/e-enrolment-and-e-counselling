import 'package:flutter/material.dart';

import '../models/payment.dart';

/// Coloured status badge for payment states.
class PaymentStatusChip extends StatelessWidget {
  final PaymentDisplayStatus status;

  const PaymentStatusChip._({required this.status});

  factory PaymentStatusChip.fromPayment(PaymentModel? payment) {
    return PaymentStatusChip._(
      status: PaymentDisplayStatus.fromPayment(payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    final label = _labelForStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static Color _colorForStatus(PaymentDisplayStatus status) {
    switch (status) {
      case PaymentDisplayStatus.notStarted:
        return Colors.grey;
      case PaymentDisplayStatus.pendingVerification:
        return Colors.orange;
      case PaymentDisplayStatus.approved:
        return Colors.green;
      case PaymentDisplayStatus.rejected:
        return Colors.red;
    }
  }

  static String _labelForStatus(PaymentDisplayStatus status) {
    switch (status) {
      case PaymentDisplayStatus.notStarted:
        return 'Not Started';
      case PaymentDisplayStatus.pendingVerification:
        return 'Pending Verification';
      case PaymentDisplayStatus.approved:
        return 'Approved';
      case PaymentDisplayStatus.rejected:
        return 'Rejected';
    }
  }
}
