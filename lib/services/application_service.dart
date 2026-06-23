import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/application.dart';
import '../models/credit_transfer_subject.dart';

/// Aggregated application metrics for the admin dashboard.
///
/// Derived from a single [ApplicationService.getAllApplications] stream so
/// counts and recent items stay in sync without extra Firestore listeners.
class ApplicationDashboardSummary {
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final List<ApplicationModel> recentApplications;

  const ApplicationDashboardSummary({
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.recentApplications,
  });

  int get totalCount => pendingCount + approvedCount + rejectedCount;
}

/// Handles Firestore persistence for student course applications.
///
/// Firestore collection : `applications`
/// Document ID strategy : auto-generated (one document per application)
///
/// This service is intentionally dependency-injection-free — callers simply
/// instantiate [ApplicationService] directly, consistent with
/// [CourseService] and [StudentInterestService].
class ApplicationService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('applications');

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Submits a new course application for [userId].
  ///
  /// Creates a document with `status = 'Pending'` and server timestamps for
  /// `appliedAt` and `updatedAt`.
  ///
  /// Throws [StateError] if the student has already applied for [courseId].
  /// Throws a [FirebaseException] on network or permission failure.
  Future<void> applyForCourse({
    required String userId,
    required String studentName,
    required String studentEmail,
    required String courseId,
    required String courseCode,
    required String courseName,
  }) async {
    if (await hasApplied(userId: userId, courseId: courseId)) {
      throw StateError(
        'Application already exists for user $userId and course $courseId',
      );
    }

    await _col.add({
      'userId': userId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseId': courseId,
      'courseCode': courseCode,
      'courseName': courseName,
      'status': ApplicationStatus.pending.firestoreValue,
      'appliedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns `true` when an application already exists for [userId] and
  /// [courseId].
  Future<bool> hasApplied({
    required String userId,
    required String courseId,
  }) async {
    final snapshot = await _col
        .where('userId', isEqualTo: userId)
        .where('courseId', isEqualTo: courseId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Returns a live stream of all applications for [userId], ordered by
  /// `appliedAt` descending (most recent first).
  ///
  /// Requires a composite Firestore index on `userId` + `appliedAt`.
  Stream<List<ApplicationModel>> getStudentApplications(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ApplicationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of all applications, ordered by `appliedAt`
  /// descending (most recent first).
  Stream<List<ApplicationModel>> getAllApplications() {
    return _col
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ApplicationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns applications whose `appliedAt` falls within [from]–[to]
  /// (inclusive calendar days in local time), ordered by `appliedAt`
  /// descending.
  Stream<List<ApplicationModel>> getApplicationsByDateRange({
    required DateTime from,
    required DateTime to,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive =
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    return _col
        .where('appliedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('appliedAt', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ApplicationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Live dashboard summary: status counts plus the [recentLimit] most recent
  /// applications, all from one Firestore listener.
  Stream<ApplicationDashboardSummary> watchDashboardSummary({
    int recentLimit = 5,
  }) {
    return getAllApplications().map((applications) {
      var pending = 0;
      var approved = 0;
      var rejected = 0;

      for (final application in applications) {
        switch (application.status) {
          case ApplicationStatus.pending:
            pending++;
          case ApplicationStatus.approved:
            approved++;
          case ApplicationStatus.rejected:
            rejected++;
        }
      }

      return ApplicationDashboardSummary(
        pendingCount: pending,
        approvedCount: approved,
        rejectedCount: rejected,
        recentApplications: applications.take(recentLimit).toList(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Admin review
  // ---------------------------------------------------------------------------

  /// Persists an admin review decision for the application at [applicationId].
  Future<void> updateApplicationReview({
    required String applicationId,
    required String status,
    required String remark,
    required String reviewedBy,
    List<CreditTransferSubject>? creditTransfers,
  }) async {
    await _col.doc(applicationId).update({
      'status': status,
      'remark': remark,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (creditTransfers != null)
        'creditTransfers':
            creditTransfers.map((subject) => subject.toMap()).toList(),
    });
  }
}
