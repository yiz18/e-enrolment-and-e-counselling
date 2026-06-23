import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/scholarship.dart';

/// Handles Firestore CRUD operations for the `scholarships` collection.
class ScholarshipService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('scholarships');

  /// Returns a live stream of all scholarships ordered by category then title.
  Stream<List<ScholarshipModel>> getScholarships() {
    return _col.orderBy('title').snapshots().map((snapshot) {
      final scholarships = snapshot.docs
          .map((doc) => ScholarshipModel.fromFirestore(doc))
          .toList();
      scholarships.sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return b.waiverPercentage.compareTo(a.waiverPercentage);
      });
      return scholarships;
    });
  }

  /// Adds a new scholarship document and returns its generated ID.
  Future<String> addScholarship(ScholarshipModel scholarship) async {
    final now = DateTime.now().toUtc();
    final doc = await _col.add({
      ...scholarship.copyWith(createdAt: now, updatedAt: now).toFirestore(),
    });
    return doc.id;
  }

  /// Updates an existing scholarship document.
  Future<void> updateScholarship(ScholarshipModel scholarship) async {
    if (scholarship.id.isEmpty) {
      throw StateError('Cannot update a scholarship without an id.');
    }

    await _col.doc(scholarship.id).update({
      ...scholarship
          .copyWith(updatedAt: DateTime.now().toUtc())
          .toFirestore(includeTimestamps: false),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes the scholarship with [id].
  Future<void> deleteScholarship(String id) async {
    await _col.doc(id).delete();
  }
}
