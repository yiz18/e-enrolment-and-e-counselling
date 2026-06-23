import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../services/appointment_service.dart';
import '../widgets/appointment_status_chip.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _appointmentService = AppointmentService();

  AppointmentModel? _appointment;
  bool _isUpdating = false;

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool get _isStatusLocked {
    final status = _appointment?.status;
    return status == AppointmentStatus.approved ||
        status == AppointmentStatus.rejected;
  }

  bool get _canAct => !_isUpdating && !_isStatusLocked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appointment ??=
        ModalRoute.of(context)?.settings.arguments as AppointmentModel?;
  }

  String _updateErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to update this appointment.';
        case 'not-found':
          return 'This appointment no longer exists.';
        case 'unavailable':
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        default:
          return error.message ??
              'Failed to update appointment. Please try again.';
      }
    }

    return 'Failed to update appointment. Please try again.';
  }

  Future<bool> _confirmStatusChange({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _updateStatus(AppointmentStatus newStatus) async {
    final appointment = _appointment;
    if (appointment == null || !_canAct) return;

    final isApprove = newStatus == AppointmentStatus.approved;
    final confirmed = await _confirmStatusChange(
      title: isApprove ? 'Approve Appointment' : 'Reject Appointment',
      message: isApprove
          ? 'Approve the appointment for ${appointment.studentName} on '
              '${_formatDate(appointment.appointmentDate.toLocal())} at '
              '${appointment.appointmentTime}?'
          : 'Reject the appointment for ${appointment.studentName} on '
              '${_formatDate(appointment.appointmentDate.toLocal())} at '
              '${appointment.appointmentTime}?',
      confirmLabel: isApprove ? 'Approve' : 'Reject',
      confirmColor: isApprove ? Colors.green : Colors.red,
    );

    if (!confirmed || !mounted) return;

    if (isApprove) {
      final hasApprovedConflict =
          await _appointmentService.hasApprovedSlotConflict(
        counsellorId: appointment.counsellorId,
        appointmentDate: appointment.appointmentDate,
        appointmentTime: appointment.appointmentTime,
        excludeAppointmentId: appointment.id,
      );

      if (hasApprovedConflict) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Slot Unavailable'),
            content: const Text(
              'Another appointment has already been approved for this slot.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isUpdating = true);

    try {
      await _appointmentService.updateStatus(
        appointmentId: appointment.id,
        status: newStatus,
      );

      if (!mounted) return;

      setState(() {
        _appointment = appointment.copyWith(status: newStatus);
      });

      var rejectedConflictCount = 0;
      if (isApprove) {
        rejectedConflictCount =
            await _appointmentService.rejectConflictingPendingAppointments(
          approvedAppointmentId: appointment.id,
          counsellorId: appointment.counsellorId,
          appointmentDate: appointment.appointmentDate,
          appointmentTime: appointment.appointmentTime,
        );
      }

      if (!mounted) return;

      setState(() => _isUpdating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApprove
                ? rejectedConflictCount > 0
                    ? 'Appointment approved. Conflicting pending requests '
                        'were automatically rejected.'
                    : 'Appointment approved.'
                : 'Appointment rejected.',
          ),
          backgroundColor: isApprove
              ? Colors.green.shade700
              : Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_updateErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _appointment;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Appointment Details"),
          backgroundColor: Colors.blueAccent,
        ),
        body: const Center(
          child: Text('Appointment not found.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Student Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRow("Student", appointment.studentName),
            _infoRow("Reason", appointment.reason),
            _infoRow("Mode", appointment.mode),
            const SizedBox(height: 20),
            const Text(
              "Appointment Details",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRow(
              "Date",
              _formatDate(appointment.appointmentDate.toLocal()),
            ),
            _infoRow("Time", appointment.appointmentTime),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      "Status:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  AppointmentStatusChip(status: appointment.status),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Remarks",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Add notes about this session...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Spacer(),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canAct
                            ? () => _updateStatus(AppointmentStatus.approved)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Approve"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canAct
                            ? () => _updateStatus(AppointmentStatus.rejected)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Reject"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Reschedule Appointment"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
