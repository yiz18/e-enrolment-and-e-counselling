import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/application.dart';
import '../models/counsellor_student_summary.dart';
import '../models/academic_result_entry.dart';
import 'application_service.dart';
import 'student_result_service.dart';

/// Builds counsellor-facing student lists from multiple Firestore collections.
///
/// Data source priority:
/// 1. [ApplicationService.getAllApplications] — name, email, status
/// 2. `studentResults` — CGPA, academic route
/// 3. `studentInterests`, `student_documents` — supplemental student IDs
class CounsellorStudentQueryService {
  final ApplicationService _applicationService = ApplicationService();
  final StudentResultService _resultService = StudentResultService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Live stream of deduplicated student summaries for counsellor records.
  Stream<List<CounsellorStudentSummary>> watchStudentSummaries() {
    return _applicationService
        .getAllApplications()
        .asyncMap(_buildSummaries);
  }

  Future<List<CounsellorStudentSummary>> _buildSummaries(
    List<ApplicationModel> applications,
  ) async {
    final accumulators = <String, _StudentAccumulator>{};

    for (final application in applications) {
      final acc = accumulators.putIfAbsent(
        application.userId,
        () => _StudentAccumulator(userId: application.userId),
      );
      if (acc.latestApplication == null) {
        acc.latestApplication = application;
        acc.name = application.studentName;
        acc.email = application.studentEmail;
      }
    }

    final knownIds = accumulators.keys.toSet();
    final supplementalIds = await _collectSupplementalStudentIds(knownIds);
    for (final userId in supplementalIds) {
      accumulators.putIfAbsent(
        userId,
        () => _StudentAccumulator(userId: userId),
      );
    }

    final summaries = <CounsellorStudentSummary>[];
    for (final acc in accumulators.values) {
      await _enrichProfile(acc);
      final results = await _resultService.getResults(acc.userId);

      summaries.add(
        CounsellorStudentSummary(
          userId: acc.userId,
          name: acc.name ?? 'Unknown Student',
          email: acc.email ?? '—',
          latestApplicationStatus: acc.latestApplication?.status,
          cgpa: _extractCgpa(results),
          academicRoute: _formatAcademicRoute(results),
        ),
      );
    }

    summaries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return summaries;
  }

  Future<void> _enrichProfile(_StudentAccumulator acc) async {
    if (acc.name != null && acc.email != null) return;

    final snapshot = await _firestore.collection('users').doc(acc.userId).get();
    if (!snapshot.exists) return;

    final user = AppUser.fromFirestore(snapshot);
    acc.name ??= user.fullName;
    acc.email ??= user.email;
  }

  Future<Set<String>> _collectSupplementalStudentIds(
    Set<String> knownIds,
  ) async {
    final supplemental = <String>{};

    for (final collection in [
      'studentResults',
      'studentInterests',
      'student_documents',
    ]) {
      final snapshot = await _firestore.collection(collection).get();
      for (final doc in snapshot.docs) {
        if (!knownIds.contains(doc.id)) {
          supplemental.add(doc.id);
        }
      }
    }

    return supplemental;
  }

  static String? _extractCgpa(StudentResultRecord? record) {
    if (record == null) return null;

    for (final entries in record.qualifications.values) {
      final cgpa = _cgpaFromEntries(entries);
      if (cgpa != null) return cgpa;
    }

    return _cgpaFromEntries(record.results);
  }

  static String? _cgpaFromEntries(List<AcademicResultEntry> entries) {
    for (final entry in entries) {
      if (entry.subject.toUpperCase() == 'CGPA' && entry.grade.isNotEmpty) {
        return entry.grade;
      }
    }
    return null;
  }

  static String? _formatAcademicRoute(StudentResultRecord? record) {
    if (record == null) return null;

    if (record.qualifications.isNotEmpty) {
      return record.qualifications.keys.join(', ');
    }

    if (record.qualificationType.isNotEmpty) {
      return record.qualificationType;
    }

    return null;
  }
}

class _StudentAccumulator {
  final String userId;
  String? name;
  String? email;
  ApplicationModel? latestApplication;

  _StudentAccumulator({required this.userId});
}
