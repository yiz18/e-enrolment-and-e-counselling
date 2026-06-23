import 'package:flutter/material.dart';

import '../models/counsellor_student_summary.dart';
import '../services/counsellor_student_query_service.dart';
import '../widgets/application_status_chip.dart';
import 'counsellor_student_detail_screen.dart';

class StudentRecordsScreen extends StatelessWidget {
  const StudentRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final queryService = CounsellorStudentQueryService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<CounsellorStudentSummary>>(
        stream: queryService.watchStudentSummaries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

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
                      'Failed to load student records.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          final students = snapshot.data ?? [];
          if (students.isEmpty) {
            return const Center(
              child: Text(
                'No student records found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final student = students[index];
              return _StudentRecordCard(
                student: student,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/counsellorStudentDetail',
                    arguments: CounsellorStudentDetailArgs(
                      studentId: student.userId,
                      studentName: student.name,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StudentRecordCard extends StatelessWidget {
  final CounsellorStudentSummary student;
  final VoidCallback onTap;

  const _StudentRecordCard({
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = student.latestApplicationStatus;
    final cgpaLabel =
        student.cgpa != null ? 'CGPA: ${student.cgpa}' : 'CGPA: Not available';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(student.email),
            const SizedBox(height: 4),
            Text(cgpaLabel),
            if (student.academicRoute != null) ...[
              const SizedBox(height: 4),
              Text('Route: ${student.academicRoute}'),
            ],
            if (status != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Application: ',
                    style: TextStyle(fontSize: 12),
                  ),
                  ApplicationStatusChip(status: status),
                ],
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
