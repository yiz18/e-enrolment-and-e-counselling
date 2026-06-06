import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import 'auth_service.dart';

/// Handles staff listing and admin-only staff account creation.
///
/// Staff accounts are created through a secondary Firebase App instance so the
/// currently signed-in admin session on the primary app is preserved.
class StaffService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  /// Streams admin and counsellor profiles from the `users` collection.
  Stream<List<AppUser>> watchStaff() {
    return _usersCol
        .where('role', whereIn: UserRole.staffRoles.toList())
        .snapshots()
        .map((snapshot) {
      final staff = snapshot.docs.map(AppUser.fromFirestore).toList();
      staff.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return staff;
    });
  }

  /// Creates a Firebase Auth account and matching `users/{uid}` staff profile.
  ///
  /// The signed-in admin on the primary Firebase app remains authenticated.
  Future<String> createStaffAccount({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    await _assertCurrentAdmin();

    if (!UserRole.staffRoles.contains(role)) {
      throw ArgumentError('role must be admin or counsellor');
    }

    final adminUid = _auth.currentUser!.uid;
    FirebaseApp? secondaryApp;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'StaffCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final now = DateTime.now().toUtc();

      await _usersCol.doc(uid).set(
            AppUser(
              uid: uid,
              email: email.trim(),
              fullName: fullName.trim(),
              authProvider: UserAuthProvider.email,
              role: role,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            ).toFirestore(),
          );

      await secondaryAuth.signOut();
      debugPrint('[StaffService] created staff users/$uid (role: $role)');

      if (_auth.currentUser?.uid != adminUid) {
        throw const AdminSessionLostException();
      }

      return uid;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<void> _assertCurrentAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const UnauthorizedStaffActionException();
    }

    final profile = await _authService.getCurrentAppUser();
    if (profile?.role != UserRole.admin) {
      throw const UnauthorizedStaffActionException();
    }
  }
}

