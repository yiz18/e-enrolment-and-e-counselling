import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../widgets/appointment_status_chip.dart';

/// Detail view for a single counselling appointment from student history.
class CounsellingHistoryDetailScreen extends StatelessWidget {
  const CounsellingHistoryDetailScreen({super.key});

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appointment =
        ModalRoute.of(context)?.settings.arguments as AppointmentModel?;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Counselling History'),
          backgroundColor: Colors.blueAccent,
        ),
        body: const Center(child: Text('Appointment not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Counselling History'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appointment Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Student', appointment.studentName),
            _infoRow(
              'Date',
              _formatDate(appointment.appointmentDate.toLocal()),
            ),
            _infoRow('Time', appointment.appointmentTime),
            _infoRow('Mode', appointment.mode),
            _infoRow('Counsellor', appointment.counsellorName),
            _infoRow('Reason', appointment.reason),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 120,
                    child: Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  AppointmentStatusChip(status: appointment.status),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appointment.remarks?.trim().isNotEmpty == true
                  ? appointment.remarks!
                  : 'No session notes recorded yet.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            const Text(
              'Follow-up Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow-up tracking coming soon.',
              style: TextStyle(color: Colors.grey.shade700),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
