import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/application.dart';

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
}
