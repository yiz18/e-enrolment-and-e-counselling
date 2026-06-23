import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_document.dart';

/// Read-only access to student document metadata for admin review.
class StudentDocumentQueryService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('student_documents');

  /// Fetches the document record for [userId], or `null` if none exists.
  Future<StudentDocumentModel?> getStudentDocuments(String userId) async {
    final snapshot = await _col.doc(userId).get();
    if (!snapshot.exists) return null;
    return StudentDocumentModel.fromFirestore(snapshot);
  }
}
