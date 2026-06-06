import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported authentication providers stored in `users/{uid}.authProvider`.
abstract final class UserAuthProvider {
  static const String email = 'email';
  static const String google = 'google';
}

/// A user profile stored at `users/{uid}` in Firestore.
class AppUser {
  /// Firebase Auth UID — also the Firestore document ID.
  final String uid;

  final String email;

  final String fullName;

  /// How the account was created: [UserAuthProvider.email] or [UserAuthProvider.google].
  final String authProvider;

  final String role;

  /// Staff accounts only. `null` for students.
  final bool? isActive;

  final DateTime createdAt;

  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.authProvider,
    required this.role,
    this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isStaffActive => isActive ?? true;

  String get statusLabel => isStaffActive ? 'Active' : 'Inactive';

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'email': email,
      'fullName': fullName,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (authProvider.isNotEmpty) {
      data['authProvider'] = authProvider;
    }
    if (isActive != null) {
      data['isActive'] = isActive;
    }

    return data;
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      authProvider: data['authProvider'] as String? ?? UserAuthProvider.email,
      role: data['role'] as String? ?? 'student',
      isActive: data['isActive'] as bool?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
    );
  }
}
