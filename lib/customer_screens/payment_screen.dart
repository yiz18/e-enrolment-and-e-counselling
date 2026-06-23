import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/application.dart';
import '../models/payment.dart';
import '../services/application_service.dart';
import '../services/course_service.dart';
import '../services/payment_service.dart';
import '../student_screens/mock_payment_processing_screen.dart';
import '../widgets/application_status_chip.dart';
import '../widgets/payment_status_chip.dart';

/// Student screen for enrollment fee payment via the simulated gateway.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _applicationService = ApplicationService();
  final _paymentService = PaymentService();
  final _courseService = CourseService();

  String? _processingApplicationId;

  static String _formatAmount(double amount) =>
      'RM ${amount.toStringAsFixed(2)}';

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<double> _resolveEnrollmentFee(String courseId) async {
    try {
      final course = await _courseService.getCourseById(courseId);
      if (course != null) {
        return AppConfig.enrollmentFeeForLevel(course.level);
      }
    } catch (_) {
      // Fall back to default fee when course lookup fails.
    }
    return AppConfig.defaultEnrollmentFee;
  }

  PaymentModel? _paymentForApplication(
    List<PaymentModel> payments,
    String applicationId,
  ) {
    for (final payment in payments) {
      if (payment.applicationId == applicationId) {
        return payment;
      }
    }
    return null;
  }

  bool _canStartPayment(PaymentModel? payment) {
    return payment == null || payment.status == PaymentStatus.rejected;
  }

  Future<void> _startPaymentFlow(
    ApplicationModel application,
    double amount,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (application.status != ApplicationStatus.approved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment is only available after your application is approved.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => _PaymentMethodSelectionDialog(amount: amount),
    );

    if (method == null || !mounted) return;

    final studentReference =
        PaymentReferenceGenerator.studentReference(user.uid);
    final billReference = PaymentReferenceGenerator.billReference(
      SimulatedPaymentType.admission,
    );

    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MockPaymentProcessingScreen(
          method: method,
          amount: amount,
          courseName: application.courseName,
          studentReference: studentReference,
          billReference: billReference,
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingApplicationId = application.id);

    try {
      final payment = await _paymentService.submitPayment(
        studentId: user.uid,
        studentName: application.studentName,
        applicationId: application.id,
        courseName: application.courseName,
        amount: amount,
        paymentMethod: method,
        studentReference: studentReference,
        billReference: billReference,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment submitted. Transaction ID: ${payment.transactionId ?? 'N/A'}. '
            'Waiting for admin verification.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingApplicationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to submit payment.'))
          : StreamBuilder<List<ApplicationModel>>(
              stream: _applicationService.getStudentApplications(user.uid),
              builder: (context, applicationSnapshot) {
                if (applicationSnapshot.hasError) {
                  return _ErrorState(
                    message:
                        'Failed to load applications.\n${applicationSnapshot.error}',
                  );
                }

                if (applicationSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final approvedApplications = (applicationSnapshot.data ?? [])
                    .where(
                      (app) => app.status == ApplicationStatus.approved,
                    )
                    .toList();

                if (approvedApplications.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No approved applications yet.\n'
                        'Payment is available after your application is approved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return StreamBuilder<List<PaymentModel>>(
                  stream: _paymentService.getStudentPayments(user.uid),
                  builder: (context, paymentSnapshot) {
                    if (paymentSnapshot.hasError) {
                      return _ErrorState(
                        message:
                            'Failed to load payments.\n${paymentSnapshot.error}',
                      );
                    }

                    if (paymentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final payments = paymentSnapshot.data ?? [];

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _PaymentInstructionsCard(),
                        const SizedBox(height: 20),
                        const Text(
                          'Your Approved Applications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < approvedApplications.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final application = approvedApplications[i];
                              final payment = _paymentForApplication(
                                payments,
                                application.id,
                              );
                              final isProcessing =
                                  _processingApplicationId == application.id;

                              return FutureBuilder<double>(
                                future:
                                    _resolveEnrollmentFee(application.courseId),
                                builder: (context, feeSnapshot) {
                                  final fee = feeSnapshot.data ??
                                      AppConfig.defaultEnrollmentFee;

                                  return _ApprovedApplicationPaymentCard(
                                    application: application,
                                    payment: payment,
                                    enrollmentFee: fee,
                                    isProcessing: isProcessing,
                                    canStartPayment: _canStartPayment(payment),
                                    formatAmount: _formatAmount,
                                    formatDate: _formatDate,
                                    onStartPayment: () =>
                                        _startPaymentFlow(application, fee),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _PaymentMethodSelectionDialog extends StatefulWidget {
  const _PaymentMethodSelectionDialog({required this.amount});

  final double amount;

  @override
  State<_PaymentMethodSelectionDialog> createState() =>
      _PaymentMethodSelectionDialogState();
}

class _PaymentMethodSelectionDialogState
    extends State<_PaymentMethodSelectionDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.fpx;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Payment Method'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enrollment Fee: RM ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...PaymentMethod.values.map(
              (method) => RadioListTile<PaymentMethod>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(method.label),
                value: method,
                groupValue: _selectedMethod,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMethod = value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedMethod),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _PaymentInstructionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap Start Payment Process on your approved application below. '
                'After completing the simulated payment, your submission will '
                'await admin verification.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovedApplicationPaymentCard extends StatelessWidget {
  const _ApprovedApplicationPaymentCard({
    required this.application,
    required this.payment,
    required this.enrollmentFee,
    required this.isProcessing,
    required this.canStartPayment,
    required this.formatAmount,
    required this.formatDate,
    required this.onStartPayment,
  });

  final ApplicationModel application;
  final PaymentModel? payment;
  final double enrollmentFee;
  final bool isProcessing;
  final bool canStartPayment;
  final String Function(double amount) formatAmount;
  final String Function(DateTime date) formatDate;
  final VoidCallback onStartPayment;

  PaymentDisplayStatus get _displayStatus =>
      PaymentDisplayStatus.fromPayment(payment);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payment_outlined,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.courseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Code: ${application.courseCode}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ApplicationStatusChip(status: application.status),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Enrollment Fee',
              value: formatAmount(enrollmentFee),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Payment Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 10),
                PaymentStatusChip.fromPayment(payment),
              ],
            ),
            if (_displayStatus ==
                PaymentDisplayStatus.pendingVerification) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Submitted',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (payment?.transactionId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Transaction ID: ${payment!.transactionId}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      payment!.displayRemarks,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (payment != null) ...[
              const SizedBox(height: 10),
              Text(
                payment!.displayRemarks,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (payment!.verifiedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Updated: ${formatDate(payment!.verifiedAt!.toLocal())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ],
            if (_displayStatus == PaymentDisplayStatus.approved) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment approved.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canStartPayment) ...[
              const SizedBox(height: 14),
              if (isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStartPayment,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Start Payment Process'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
