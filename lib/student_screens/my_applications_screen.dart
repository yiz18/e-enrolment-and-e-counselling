import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/application.dart';
import '../services/application_service.dart';
import '../widgets/application_status_chip.dart';

/// Lists all course applications for the signed-in student.
class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final applicationService = ApplicationService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Applications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: user == null
          ? const Center(
              child: Text('Please sign in to view your applications.'),
            )
          : StreamBuilder<List<ApplicationModel>>(
              stream: applicationService.getStudentApplications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load applications: ${snapshot.error}'),
                  );
                }

                final applications = snapshot.data ?? [];

                if (applications.isEmpty) {
                  return const Center(
                    child: Text('You have not applied for any courses yet.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: applications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final application = applications[index];
                    return _ApplicationCard(
                      application: application,
                      formattedDate: _formatDate(application.appliedAt.toLocal()),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ApplicationModel application;
  final String formattedDate;

  const _ApplicationCard({
    required this.application,
    required this.formattedDate,
  });

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
                Expanded(
                  child: Text(
                    application.courseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ApplicationStatusChip(status: application.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Code: ${application.courseCode}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Applied: $formattedDate',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
