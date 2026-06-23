import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/student_profile.dart';
import 'cloudinary_service.dart';

/// Loads and updates student profile data in `users/{uid}`.
class UserProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  static const _allowedExtensions = {'jpg', 'jpeg', 'png'};

  /// Returns the signed-in student's profile, or `null` when not signed in.
  Future<StudentProfile?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _usersCol.doc(user.uid).get();
    return _profileFromSnapshot(snapshot, user);
  }

  /// Live stream of the signed-in student's profile from `users/{uid}`.
  ///
  /// Emits whenever profile fields (including [StudentProfile.profileImageUrl])
  /// change in Firestore.
  Stream<StudentProfile?> watchCurrentProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _usersCol.doc(user.uid).snapshots().map(
          (snapshot) => _profileFromSnapshot(snapshot, user),
        );
  }

  StudentProfile _profileFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    User user,
  ) {
    final appUser = snapshot.exists ? AppUser.fromFirestore(snapshot) : null;

    return StudentProfile.fromSources(
      authUser: user,
      userDocument: snapshot.data() ?? {},
      appUser: appUser,
    );
  }

  /// Updates editable profile fields on `users/{uid}`.
  Future<void> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? icPassportNumber,
    String? gender,
    String? address,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please sign in to update your profile.');
    }

    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Full Name cannot be empty.');
    }

    await _usersCol.doc(uid).set(
      {
        'fullName': trimmedName,
        'phoneNumber': phoneNumber?.trim() ?? '',
        'icPassportNumber': icPassportNumber?.trim() ?? '',
        'gender': gender?.trim() ?? '',
        'address': address?.trim() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Uploads [file] to Cloudinary and stores the URL in `profileImageUrl`.
  Future<String> uploadProfilePhoto(XFile file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please sign in to upload a profile photo.');
    }

    _validateImageFilename(file.name);

    final imageUrl = await CloudinaryService.uploadXFile(file);

    await _usersCol.doc(uid).set(
      {
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return imageUrl;
  }

  void _validateImageFilename(String filename) {
    final trimmed = filename.trim();
    if (trimmed.isEmpty || !trimmed.contains('.')) {
      return;
    }

    final extension = trimmed.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw ArgumentError('Only JPG, JPEG, and PNG images are accepted.');
    }
  }
}
