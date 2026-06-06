import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// =============================================================================
// StudentSession — development-only session helper
// =============================================================================

/// A lightweight, development-only session stub that provides a stable
/// [currentStudentId] without Firebase Auth or a login screen.
///
/// **Purpose:** During FYP development, OCR may occasionally fail to parse the
/// IC number from a test document.  Instead of the system falling back to
/// `'guest_user'` (which creates a throwaway Firestore document unrelated to
/// any real student record), all three key screens — Upload, ParsedResult, and
/// Recommendation — read [currentStudentId] from this class so every test run
/// writes to and reads from the same Firestore document.
///
/// **How to change the ID at runtime:**
/// ```dart
/// StudentSession.setStudentId('990101012345');
/// ```
///
/// **How to reset to the default:**
/// ```dart
/// StudentSession.reset();
/// ```
///
/// ### ⚠️ Development-only
/// This class bypasses authentication entirely.  Before any production release,
/// replace all [StudentSession.currentStudentId] references with the Firebase
/// Auth UID of the signed-in user.
///
/// ### Default value
/// `'011018070829'` — the IC digit string for the primary test student whose
/// academic records are already seeded in Firestore.
class StudentSession {
  StudentSession._(); // not instantiable

  /// Default dev fallback when no Firebase user is signed in.
  static const String _defaultDevStudentId = '011018070829';

  /// Optional override for local testing without Firebase Auth.
  static String? _devOverrideId;

  /// The active student ID for Firestore reads and writes.
  ///
  /// Uses the signed-in Firebase Auth UID when available; otherwise falls back
  /// to a dev override or [_defaultDevStudentId].
  static String get currentStudentId =>
      FirebaseAuth.instance.currentUser?.uid ??
      _devOverrideId ??
      _defaultDevStudentId;

  // ---------------------------------------------------------------------------
  // Mutators
  // ---------------------------------------------------------------------------

  /// Changes [currentStudentId] to [id] and prints a confirmation to the
  /// debug console.
  ///
  /// No-op in release builds (the [debugPrint] call is compiled out, but the
  /// assignment still runs — gate the call site with [kDebugMode] to prevent
  /// the ID from being changed in production).
  static void setStudentId(String id) {
    _devOverrideId = id;
    debugPrint('[StudentSession] dev override → "$id"');
  }

  /// Clears any dev override and returns to the default fallback ID.
  static void reset() {
    _devOverrideId = null;
    debugPrint('[StudentSession] reset → "$currentStudentId"');
  }
}

// =============================================================================
// StudentSessionBanner — dev-only UI indicator
// =============================================================================

/// A compact amber banner that shows the active [StudentSession.currentStudentId].
///
/// Drop this into any screen that reads [StudentSession.currentStudentId] so
/// developers can immediately see which Firestore document is being targeted
/// during a test run.
///
/// The banner is automatically hidden in release builds via [kDebugMode].
/// Nothing needs to be removed before shipping.
///
/// ### Usage
/// ```dart
/// // Inside a Column or as a leading child in a scrollable body:
/// const StudentSessionBanner(),
/// ```
class StudentSessionBanner extends StatelessWidget {
  const StudentSessionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFF3CD), // amber-50 equivalent
      child: Row(
        children: [
          const Icon(Icons.developer_mode,
              size: 15, color: Color(0xFF856404)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEV SESSION  ·  Student ID: '
              '${StudentSession.currentStudentId}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF856404),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
