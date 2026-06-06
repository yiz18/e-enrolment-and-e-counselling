import 'package:cloud_firestore/cloud_firestore.dart';

/// The six Holland/RIASEC interest codes, in standard order.
///
/// Used for validation when constructing a [StudentInterest].
const Set<String> kValidRiasecCodes = {'R', 'I', 'A', 'S', 'E', 'C'};

/// The number of interest codes a student must select.
const int kRequiredRiasecCount = 3;

// =============================================================================
// Model
// =============================================================================

/// A student's self-reported RIASEC interest profile.
///
/// Students discover their profile externally (via the O*NET Interest
/// Profiler at https://www.mynextmove.org/explore/ip) and then enter
/// their top three Holland codes into the app.
///
/// ### Firestore document shape
///
/// ```json
/// {
///   "riasecCodes": ["I", "E", "A"],
///   "updatedAt":   Timestamp(2026-06-04T08:00:00Z)
/// }
/// ```
///
/// Stored in the `studentInterests` collection, with [userId] as the
/// document ID — the same identifier used in `studentResults`.
///
/// ### Code ordering convention
///
/// [riasecCodes] is ordered strongest → weakest, matching the O*NET
/// Interest Profiler's three-letter Summary Code output.
/// `riasecCodes[0]` is the student's primary interest area.
class StudentInterest {
  /// Firebase user ID — also the Firestore document ID.
  final String userId;

  /// Ordered list of exactly [kRequiredRiasecCount] Holland letter codes.
  ///
  /// Each element is one of `R`, `I`, `A`, `S`, `E`, `C`.
  /// Index 0 is the student's dominant interest; index 2 is tertiary.
  final List<String> riasecCodes;

  /// UTC timestamp of the last time this profile was saved or updated.
  final DateTime updatedAt;

  const StudentInterest({
    required this.userId,
    required this.riasecCodes,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Converts this record to the Firestore document map.
  ///
  /// The [userId] is not written into the document body — it is the document
  /// ID, consistent with the `studentResults` collection convention.
  Map<String, dynamic> toFirestore() => {
        'riasecCodes': List<String>.unmodifiable(riasecCodes),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Constructs a [StudentInterest] from a Firestore [DocumentSnapshot].
  ///
  /// Tolerates missing or malformed fields so that partial documents (e.g.
  /// from older schema versions) do not throw at runtime.
  factory StudentInterest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rawCodes = data['riasecCodes'] as List? ?? [];
    final codes = rawCodes
        .whereType<String>()
        .where((c) => kValidRiasecCodes.contains(c))
        .toList();

    final updatedAt =
        (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc();

    return StudentInterest(
      userId: doc.id,
      riasecCodes: codes,
      updatedAt: updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when this profile contains exactly [kRequiredRiasecCount]
  /// valid, distinct Holland codes.
  bool get isComplete =>
      riasecCodes.length == kRequiredRiasecCount &&
      riasecCodes.toSet().length == kRequiredRiasecCount &&
      riasecCodes.every(kValidRiasecCodes.contains);

  /// Creates a copy of this record with [riasecCodes] and a refreshed
  /// [updatedAt] timestamp.
  StudentInterest copyWithCodes(List<String> newCodes) => StudentInterest(
        userId: userId,
        riasecCodes: newCodes,
        updatedAt: DateTime.now().toUtc(),
      );

  @override
  String toString() =>
      'StudentInterest('
      'userId: "$userId", '
      'codes: ${riasecCodes.join('-')}, '
      'updatedAt: ${updatedAt.toIso8601String()}'
      ')';
}
