import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/student_interest.dart';

// =============================================================================
// Service
// =============================================================================

/// Handles Firestore persistence for a student's RIASEC interest profile.
///
/// Firestore collection : `studentInterests`
/// Document ID strategy : [userId] (one document per student)
///
/// Students self-report their top 3 Holland codes after completing the
/// external O*NET Interest Profiler (https://www.mynextmove.org/explore/ip).
/// This service stores and retrieves those codes so the recommendation screen
/// can rank eligible courses by interest alignment.
///
/// This service is intentionally dependency-injection-free — callers simply
/// instantiate [StudentInterestService] directly, consistent with
/// [StudentResultService] and [CourseService].
///
/// ### Relationship to other collections
///
/// | Collection        | Document ID | Purpose                        |
/// |-------------------|-------------|--------------------------------|
/// | studentResults    | userId      | Academic grades (SPM, STPM …)  |
/// | studentInterests  | userId      | RIASEC interest profile        |
///
/// The same [userId] (IC digits from OCR, or `'guest_user'`) is used across
/// both collections so that the recommendation screen can load both with a
/// single identifier.
class StudentInterestService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('studentInterests');

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Saves [riasecCodes] as the interest profile for [userId].
  ///
  /// Creates a new document if one does not yet exist, or fully replaces an
  /// existing document.  Use [updateInterests] when you want to be explicit
  /// that the document must already exist.
  ///
  /// [riasecCodes] must contain exactly [kRequiredRiasecCount] distinct,
  /// valid Holland letter codes (`R`, `I`, `A`, `S`, `E`, `C`).
  ///
  /// Throws an [ArgumentError] if the supplied codes fail validation.
  /// Throws a [FirebaseException] on network or permission failure.
  Future<void> saveInterests(
    String userId,
    List<String> riasecCodes,
  ) async {
    _validateCodes(riasecCodes);

    await _col.doc(userId).set({
      'riasecCodes': List<String>.from(riasecCodes),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }

  /// Updates an existing interest profile for [userId] with [riasecCodes].
  ///
  /// Unlike [saveInterests], this uses Firestore `update()` which will throw
  /// a [FirebaseException] (`not-found`) if the document does not yet exist.
  /// Prefer [saveInterests] when you are unsure whether the document exists.
  ///
  /// [riasecCodes] must contain exactly [kRequiredRiasecCount] distinct,
  /// valid Holland letter codes.
  ///
  /// Throws an [ArgumentError] if the supplied codes fail validation.
  /// Throws a [FirebaseException] on network or permission failure.
  Future<void> updateInterests(
    String userId,
    List<String> riasecCodes,
  ) async {
    _validateCodes(riasecCodes);

    await _col.doc(userId).update({
      'riasecCodes': List<String>.from(riasecCodes),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Retrieves the [StudentInterest] profile for [userId].
  ///
  /// Returns `null` when no document exists for the given [userId] — i.e. the
  /// student has not yet entered their RIASEC codes.  The recommendation screen
  /// treats a `null` result as "no interests set" and falls back to alphabetical
  /// sorting.
  ///
  /// Throws a [FirebaseException] on network or permission failure.
  Future<StudentInterest?> getInterests(String userId) async {
    final doc = await _col.doc(userId).get();
    if (!doc.exists) return null;
    return StudentInterest.fromFirestore(doc);
  }

  // ---------------------------------------------------------------------------
  // Debug / verification
  // ---------------------------------------------------------------------------

  /// Saves [riasecCodes] for [userId], immediately reads them back, and prints
  /// the result to the debug console.
  ///
  /// This method exists solely for development verification.  Call it once from
  /// a temporary button or initState to confirm that Firestore read/write
  /// permissions are correctly configured for the `studentInterests` collection.
  ///
  /// **Remove or gate behind `kDebugMode` before production release.**
  ///
  /// Example output on success:
  /// ```
  /// [StudentInterestService] debugVerify ▶ saving I-E-A for user test_user_001
  /// [StudentInterestService] debugVerify ✓ save succeeded
  /// [StudentInterestService] debugVerify ✓ read succeeded → StudentInterest(userId: "test_user_001", codes: I-E-A, updatedAt: 2026-06-04T08:00:00.000Z)
  /// [StudentInterestService] debugVerify ✓ isComplete = true
  /// [StudentInterestService] debugVerify ✓ PASSED — Firestore read/write working correctly.
  /// ```
  Future<void> debugVerify(String userId, List<String> riasecCodes) async {
    assert(kDebugMode, 'debugVerify must only be called in debug builds.');

    debugPrint(
      '[StudentInterestService] debugVerify ▶ '
      'saving ${riasecCodes.join("-")} for user $userId',
    );

    try {
      await saveInterests(userId, riasecCodes);
      debugPrint('[StudentInterestService] debugVerify ✓ save succeeded');
    } catch (e) {
      debugPrint('[StudentInterestService] debugVerify ✗ save FAILED: $e');
      return;
    }

    try {
      final record = await getInterests(userId);
      if (record == null) {
        debugPrint(
          '[StudentInterestService] debugVerify ✗ read returned null '
          '(document missing after save — check Firestore rules)',
        );
        return;
      }

      debugPrint(
        '[StudentInterestService] debugVerify ✓ read succeeded → $record',
      );
      debugPrint(
        '[StudentInterestService] debugVerify ✓ '
        'isComplete = ${record.isComplete}',
      );

      final codesMatch =
          record.riasecCodes.length == riasecCodes.length &&
          List.generate(
            riasecCodes.length,
            (i) => record.riasecCodes[i] == riasecCodes[i],
          ).every((ok) => ok);

      if (codesMatch) {
        debugPrint(
          '[StudentInterestService] debugVerify ✓ '
          'PASSED — Firestore read/write working correctly.',
        );
      } else {
        debugPrint(
          '[StudentInterestService] debugVerify ✗ '
          'MISMATCH — saved ${riasecCodes.join("-")} '
          'but read back ${record.riasecCodes.join("-")}',
        );
      }
    } catch (e) {
      debugPrint('[StudentInterestService] debugVerify ✗ read FAILED: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal validation
  // ---------------------------------------------------------------------------

  /// Validates that [codes] contains exactly [kRequiredRiasecCount] distinct
  /// Holland codes, each of which is a member of [kValidRiasecCodes].
  ///
  /// Throws [ArgumentError] describing the specific violation.
  void _validateCodes(List<String> codes) {
    if (codes.length != kRequiredRiasecCount) {
      throw ArgumentError(
        'riasecCodes must contain exactly $kRequiredRiasecCount codes; '
        'got ${codes.length}: $codes',
      );
    }

    final invalid = codes.where((c) => !kValidRiasecCodes.contains(c));
    if (invalid.isNotEmpty) {
      throw ArgumentError(
        'Invalid RIASEC code(s): ${invalid.join(", ")}. '
        'Valid codes are: ${kValidRiasecCodes.join(", ")}',
      );
    }

    final unique = codes.toSet();
    if (unique.length != codes.length) {
      final duplicates = codes.where(
        (c) => codes.indexOf(c) != codes.lastIndexOf(c),
      );
      throw ArgumentError(
        'riasecCodes must all be distinct; '
        'duplicate(s) found: ${duplicates.toSet().join(", ")}',
      );
    }
  }
}
