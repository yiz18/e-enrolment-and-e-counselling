import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';

/// Handles Firebase Authentication and `users/{uid}` profile documents.
class AuthService {
  AuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static bool _googleSignInInitialized = false;
  static Future<void>? _googleSignInInitFuture;

  /// Registers a new student with email and password.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    await _createUserDocument(
      uid: uid,
      email: email.trim(),
      fullName: fullName.trim(),
      authProvider: UserAuthProvider.email,
      role: UserRole.student,
    );
  }

  /// Signs in a student with email and password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = _auth.currentUser!;
    await _ensureUserDocument(
      uid: user.uid,
      email: user.email ?? email.trim(),
      fullName: user.displayName,
      authProvider: UserAuthProvider.email,
      role: UserRole.student,
    );

    await _validateSignedInRole(expectedRole: UserRole.student);
  }

  /// Signs in admin or counsellor staff with email and password.
  Future<AppUser> signInStaff({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    return _validateSignedInRole(expectedRole: expectedRole);
  }

  /// Signs in a student with Google.
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      rethrow;
    }

    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    await _ensureUserDocument(
      uid: user.uid,
      email: user.email ?? googleUser.email,
      fullName: user.displayName ?? googleUser.displayName,
      authProvider: UserAuthProvider.google,
      role: UserRole.student,
    );

    await _validateSignedInRole(expectedRole: UserRole.student);
  }

  /// Loads the signed-in user's Firestore profile, if it exists.
  Future<AppUser?> getCurrentAppUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final snapshot = await _usersCol.doc(uid).get();
    if (!snapshot.exists) return null;

    return AppUser.fromFirestore(snapshot);
  }

  Future<void> signOut() async {
    final signOutTasks = <Future<void>>[_auth.signOut()];
    if (_googleSignInInitialized) {
      signOutTasks.insert(0, _googleSignIn.signOut());
    }
    await Future.wait(signOutTasks);
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    _googleSignInInitFuture ??= _initializeGoogleSignIn();
    try {
      await _googleSignInInitFuture;
      _googleSignInInitialized = true;
    } catch (e) {
      _googleSignInInitFuture = null;
      rethrow;
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      if (kIsWeb) {
        const webClientId = String.fromEnvironment(
          'GOOGLE_SIGN_IN_WEB_CLIENT_ID',
          defaultValue: '',
        );
        if (webClientId.isEmpty) {
          throw const GoogleSignInNotConfiguredException();
        }
        await _googleSignIn.initialize(clientId: webClientId);
      } else {
        await _googleSignIn.initialize();
      }
    } on GoogleSignInNotConfiguredException {
      rethrow;
    } catch (e, stack) {
      debugPrint('[AuthService] Google Sign-In init failed: $e\n$stack');
      throw const GoogleSignInNotConfiguredException();
    }
  }

  Future<AppUser> _validateSignedInRole({required String expectedRole}) async {
    final profile = await getCurrentAppUser();
    if (profile == null) {
      await _auth.signOut();
      throw const UserProfileNotFoundException();
    }

    if (profile.role != expectedRole) {
      await _auth.signOut();
      throw RoleMismatchException(
        expectedRole: expectedRole,
        actualRole: profile.role,
      );
    }

    if (UserRole.staffRoles.contains(profile.role) && !profile.isStaffActive) {
      await _auth.signOut();
      throw const StaffInactiveException();
    }

    return profile;
  }

  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String fullName,
    required String authProvider,
    required String role,
  }) async {
    final now = DateTime.now().toUtc();
    final profile = AppUser(
      uid: uid,
      email: email,
      fullName: fullName,
      authProvider: authProvider,
      role: role,
      createdAt: now,
      updatedAt: now,
    );

    await _usersCol.doc(uid).set(profile.toFirestore());
    debugPrint('[AuthService] created users/$uid (role: $role)');
  }

  Future<void> _ensureUserDocument({
    required String uid,
    required String email,
    String? fullName,
    required String authProvider,
    required String role,
  }) async {
    final docRef = _usersCol.doc(uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      debugPrint('[AuthService] using existing users/$uid');
      return;
    }

    await _createUserDocument(
      uid: uid,
      email: email,
      fullName: (fullName ?? '').trim().isEmpty ? email : fullName!.trim(),
      authProvider: authProvider,
      role: role,
    );
  }
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

class GoogleSignInNotConfiguredException implements Exception {
  const GoogleSignInNotConfiguredException();
}

class UserProfileNotFoundException implements Exception {
  const UserProfileNotFoundException();
}

class RoleMismatchException implements Exception {
  const RoleMismatchException({
    required this.expectedRole,
    required this.actualRole,
  });

  final String expectedRole;
  final String actualRole;
}

class StaffInactiveException implements Exception {
  const StaffInactiveException();
}

class UnauthorizedStaffActionException implements Exception {
  const UnauthorizedStaffActionException();
}

class AdminSessionLostException implements Exception {
  const AdminSessionLostException();
}

String authErrorMessage(Object error) {
  if (error is AuthCancelledException) {
    return 'Google sign-in was cancelled.';
  }

  if (error is GoogleSignInNotConfiguredException) {
    return 'Google Sign-In is not configured yet. Please use email and password.';
  }

  if (error is UserProfileNotFoundException) {
    return 'Account profile not found. Please contact support.';
  }

  if (error is RoleMismatchException) {
    return 'This account is not authorized for this login portal.';
  }

  if (error is StaffInactiveException) {
    return 'This staff account has been deactivated.';
  }

  if (error is UnauthorizedStaffActionException) {
    return 'Only admins can manage staff accounts.';
  }

  if (error is AdminSessionLostException) {
    return 'Staff account was created, but the admin session was interrupted. Please sign in again.';
  }

  if (error is GoogleSignInException) {
    return error.description ?? 'Google sign-in failed. Please try again.';
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  return 'Something went wrong. Please try again.';
}
