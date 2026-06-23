import 'application.dart';

/// Aggregated student row for the counsellor student records list.
class CounsellorStudentSummary {
  final String userId;
  final String name;
  final String email;
  final ApplicationStatus? latestApplicationStatus;
  final String? cgpa;
  final String? academicRoute;

  const CounsellorStudentSummary({
    required this.userId,
    required this.name,
    required this.email,
    this.latestApplicationStatus,
    this.cgpa,
    this.academicRoute,
  });
}
