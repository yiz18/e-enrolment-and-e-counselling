import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';

/// Handles all Firestore CRUD operations for the [Course] collection.
///
/// Firestore collection : `courses`
/// Document ID strategy : course [code] (e.g. `BCS`, `BIT`)
///
/// This service is intentionally dependency-injection-free — callers simply
/// instantiate [CourseService] directly.  When a state-management layer is
/// introduced in the future, convert this to a singleton or injectable.
class CourseService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('courses');

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns a live [Stream] of all courses ordered by course code.
  /// The [StreamBuilder] in [CourseManagementScreen] subscribes to this stream
  /// so the table and stat cards update automatically after any write.
  Stream<List<Course>> getCoursesStream() {
    return _col.orderBy('code').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList(),
        );
  }

  /// Returns a one-time snapshot of all **active** courses, ordered by code.
  ///
  /// Uses the same `orderBy('code')` index as [getCoursesStream] so no
  /// additional composite Firestore index is required.  The `isActive` filter
  /// is applied in Dart after the fetch.
  ///
  /// Used by [RecommendationScreen] which evaluates all eligible courses once
  /// at load time and does not need live updates.
  Future<List<Course>> getActiveCourses() async {
    final snapshot = await _col.orderBy('code').get();
    return snapshot.docs
        .map((doc) => Course.fromFirestore(doc))
        .where((course) => course.isActive)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Adds a new course document.
  /// Uses [course.code] as the Firestore document ID so documents are
  /// human-readable and addressable without a secondary lookup.
  ///
  /// Throws a [FirebaseException] if a document with the same code already
  /// exists and Firestore security rules disallow overwrites.
  Future<void> addCourse(Course course) async {
    await _col.doc(course.code).set(course.toFirestore());
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Overwrites the document identified by [course.id] with the new data.
  /// [course.id] equals [course.code] for all records created by this app.
  Future<void> updateCourse(Course course) async {
    await _col.doc(course.id).set(course.toFirestore());
  }

  // ---------------------------------------------------------------------------
  // Patch
  // ---------------------------------------------------------------------------

  /// Updates only the `interestTags` field for the document with [id].
  ///
  /// Uses Firestore `update()` — a partial write — so every other field
  /// (including `admissionPathways`) is left completely unchanged.
  Future<void> patchInterestTags(String id, List<String> tags) async {
    await _col.doc(id).update({'interestTags': tags});
  }

  /// Finds the first course whose `name` exactly matches [courseName] and
  /// updates only its `interestTags` field.
  ///
  /// Returns `true` when a matching document was found and updated,
  /// `false` when no document matched.
  Future<bool> patchInterestTagsByName(
      String courseName, List<String> tags) async {
    final snap =
        await _col.where('name', isEqualTo: courseName).limit(1).get();
    if (snap.docs.isEmpty) return false;
    await snap.docs.first.reference.update({'interestTags': tags});
    return true;
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Permanently deletes the course document with the given [id].
  Future<void> deleteCourse(String id) async {
    await _col.doc(id).delete();
  }
}
