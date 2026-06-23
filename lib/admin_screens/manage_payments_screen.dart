import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/payment.dart';
import '../navigation/logout_navigation.dart';
import '../services/payment_service.dart';
import '../widgets/payment_status_chip.dart';

/// Admin screen for reviewing and verifying student payment receipts.
///
/// Implements **UC_0XX: Make Enrollment Payment** — steps 6–8.
class ManagePaymentsScreen extends StatefulWidget {
  const ManagePaymentsScreen({super.key});

  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen> {
  final _service = PaymentService();

  static String _formatAmount(double amount) =>
      'RM ${amount.toStringAsFixed(2)}';

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Payments'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 768)
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'logout') {
                  logoutToRoleSelection(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.pushNamed(context, '/adminProfile'),
            ),
        ],
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: _service.getAllPayments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load payments.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return const Center(
              child: Text(
                'No payment submissions yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentCard(
                payment: payment,
                formattedAmount: _formatAmount(payment.amount),
                formattedDate: _formatDate(payment.createdAt.toLocal()),
                onTap: () => _showReviewDialog(context, payment),
              );
            },
          );
        },
      ),
    );
  }

  void _showReviewDialog(BuildContext context, PaymentModel payment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PaymentReviewDialog(
        payment: payment,
        formattedDate: _formatDate(payment.createdAt.toLocal()),
        formattedAmount: _formatAmount(payment.amount),
        onApprove: (remarks) async {
          final adminUid = FirebaseAuth.instance.currentUser?.uid;
          if (adminUid == null) {
            throw StateError('Admin is not signed in.');
          }

          await _service.approvePayment(
            paymentId: payment.id,
            verifiedBy: adminUid,
            remarks: remarks,
          );
        },
        onReject: (remarks) async {
          final adminUid = FirebaseAuth.instance.currentUser?.uid;
          if (adminUid == null) {
            throw StateError('Admin is not signed in.');
          }

          await _service.rejectPayment(
            paymentId: payment.id,
            verifiedBy: adminUid,
            remarks: remarks,
          );
        },
        onSuccess: (message) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        },
        onError: (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update payment: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.formattedAmount,
    required this.formattedDate,
    required this.onTap,
  });

  final PaymentModel payment;
  final String formattedAmount;
  final String formattedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.studentName.isNotEmpty
                              ? payment.studentName
                              : payment.studentId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.courseName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PaymentStatusChip.fromPayment(payment),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                formattedAmount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 8),
              _MetaLine(
                icon: Icons.confirmation_number_outlined,
                label: 'Transaction ID',
                value: payment.transactionId ?? '—',
              ),
              const SizedBox(height: 4),
              _MetaLine(
                icon: Icons.badge_outlined,
                label: 'Student Ref',
                value: payment.studentReference ?? '—',
              ),
              const SizedBox(height: 4),
              _MetaLine(
                icon: Icons.receipt_long_outlined,
                label: 'Bill Ref',
                value: payment.billReference ?? '—',
              ),
              const SizedBox(height: 4),
              _MetaLine(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payment Method',
                value: payment.paymentMethodLabel,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted: $formattedDate',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _PaymentReviewDialog extends StatefulWidget {
  const _PaymentReviewDialog({
    required this.payment,
    required this.formattedDate,
    required this.formattedAmount,
    required this.onApprove,
    required this.onReject,
    required this.onSuccess,
    required this.onError,
  });

  final PaymentModel payment;
  final String formattedDate;
  final String formattedAmount;
  final Future<void> Function(String? remarks) onApprove;
  final Future<void> Function(String? remarks) onReject;
  final void Function(String message) onSuccess;
  final void Function(Object error) onError;

  @override
  State<_PaymentReviewDialog> createState() => _PaymentReviewDialogState();
}

class _PaymentReviewDialogState extends State<_PaymentReviewDialog> {
  final _remarkController = TextEditingController();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _remarkController.text = widget.payment.remarks ?? '';
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    setState(() => _processing = true);
    try {
      await widget.onApprove(_remarkController.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess('Payment approved successfully');
    } catch (e) {
      if (!mounted) return;
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _processing = true);
    try {
      await widget.onReject(_remarkController.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess('Payment rejected');
    } catch (e) {
      if (!mounted) return;
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openReceipt() async {
    if (!widget.payment.hasReceipt) return;

    final uri = Uri.parse(widget.payment.receiptUrl!);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open receipt link.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final isPending = payment.status.isAwaitingVerification;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payment, color: Colors.blueAccent, size: 22),
          SizedBox(width: 8),
          Text('Payment Review', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Payment Information'),
              const SizedBox(height: 10),
              _DetailRow(
                label: 'Student',
                value: payment.studentName.isNotEmpty
                    ? payment.studentName
                    : payment.studentId,
              ),
              _DetailRow(label: 'Course', value: payment.courseName),
              _DetailRow(label: 'Amount', value: widget.formattedAmount),
              _DetailRow(
                label: 'Transaction ID',
                value: payment.transactionId ?? '—',
              ),
              _DetailRow(
                label: 'Student Ref',
                value: payment.studentReference ?? '—',
              ),
              _DetailRow(
                label: 'Bill Ref',
                value: payment.billReference ?? '—',
              ),
              _DetailRow(
                label: 'Payment Method',
                value: payment.paymentMethodLabel,
              ),
              _DetailRow(label: 'Submitted', value: widget.formattedDate),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  PaymentStatusChip.fromPayment(payment),
                ],
              ),
              if (payment.hasReceipt) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openReceipt,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View Legacy Receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: _remarkController,
                maxLines: 3,
                enabled: !_processing,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'e.g. Payment verified successfully',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (isPending) ...[
          OutlinedButton(
            onPressed: _processing ? null : _handleReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: _processing ? null : _handleApprove,
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Approve'),
          ),
        ] else
          ElevatedButton(
            onPressed: _processing
                ? null
                : () async {
                    setState(() => _processing = true);
                    try {
                      await PaymentService().updatePaymentRemarks(
                        paymentId: payment.id,
                        remarks: _remarkController.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      widget.onSuccess('Payment remarks updated');
                    } catch (e) {
                      if (!mounted) return;
                      widget.onError(e);
                    } finally {
                      if (mounted) setState(() => _processing = false);
                    }
                  },
            child: const Text('Save Remarks'),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.blueAccent,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
