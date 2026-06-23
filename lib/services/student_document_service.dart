import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_document.dart';
import 'cloudinary_service.dart';

/// Handles Cloudinary uploads and Firestore metadata for student documents.
class StudentDocumentService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('student_documents');

  static const _allowedExtensions = {'jpg', 'jpeg', 'png'};

  /// Live stream of the student's document record. Returns `null` when none
  /// exists yet.
  Stream<StudentDocumentModel?> watchStudentDocuments(String userId) {
    return _col.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return StudentDocumentModel.fromFirestore(snapshot);
    });
  }

  /// Uploads [file] to Cloudinary and appends the image URL to Firestore.
  Future<void> uploadDocument({
    required String userId,
    required StudentDocumentType type,
    required File file,
  }) async {
    _validateImageFile(file);

    final imageUrl = await CloudinaryService.uploadImage(file);

    await _col.doc(userId).set(
      {
        'userId': userId,
        type.urlsField: FieldValue.arrayUnion([imageUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Removes [url] from the Firestore array for [type] without deleting the
  /// Cloudinary asset.
  Future<void> deleteDocumentUrl({
    required String userId,
    required StudentDocumentType type,
    required String url,
  }) async {
    await _col.doc(userId).update({
      type.urlsField: FieldValue.arrayRemove([url]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _validateImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw ArgumentError(
        'Only JPG, JPEG, and PNG images are accepted.',
      );
    }
  }
}
