import 'package:firebase_auth/firebase_auth.dart';

import 'app_user.dart';

/// Student profile fields stored in `users/{uid}` alongside [AppUser] auth data.
class StudentProfile {
  const StudentProfile({
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.icPassportNumber,
    this.gender,
    this.address,
    this.profileImageUrl,
  });

  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final String? icPassportNumber;
  final String? gender;
  final String? address;
  final String? profileImageUrl;

  factory StudentProfile.fromSources({
    required User authUser,
    required Map<String, dynamic> userDocument,
    required AppUser? appUser,
  }) {
    String? readString(Object? value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    String? firstNonEmpty(Iterable<String?> values) {
      for (final value in values) {
        final text = value?.trim();
        if (text != null && text.isNotEmpty) return text;
      }
      return null;
    }

    return StudentProfile(
      fullName: firstNonEmpty([
        appUser?.fullName,
        readString(authUser.displayName),
      ]),
      email: firstNonEmpty([
        appUser?.email,
        readString(authUser.email),
      ]),
      phoneNumber: firstNonEmpty([
        readString(userDocument['phoneNumber']),
        readString(userDocument['phone']),
      ]),
      icPassportNumber: firstNonEmpty([
        readString(userDocument['icPassportNumber']),
        readString(userDocument['icNumber']),
        readString(userDocument['ic']),
        readString(userDocument['passportNumber']),
      ]),
      gender: readString(userDocument['gender']),
      address: readString(userDocument['address']),
      profileImageUrl: readString(userDocument['profileImageUrl']),
    );
  }
}
