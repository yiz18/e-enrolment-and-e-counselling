import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_result_entry.dart';

// =============================================================================
// Record model
// =============================================================================

/// A Firestore-persisted snapshot of a student's OCR-parsed academic results
/// supporting multiple qualification types (SPM, STPM, A-Level, UEC, etc.).
///
/// Stored in the `studentResults` collection with the student's user ID as the
/// document ID.  Uploading a new qualification merges into the existing
/// document — earlier qualifications are never overwritten.
///
/// ### Firestore document shape (v2 — multi-qualification)
///
/// ```json
/// {
///   "userId":   "uid_abc123",
///   "updatedAt": Timestamp(2026-06-03T04:37:00Z),
///   "qualifications": {
///     "SPM":  [
///       { "subject": "Mathematics",            "grade": "A"  },
///       { "subject": "Additional Mathematics", "grade": "B+" },
///       { "subject": "English",                "grade": "C"  }
///     ],
///     "STPM": [
///       { "subject": "Mathematics T",          "grade": "B"  },
///       { "subject": "Physics",                "grade": "C"  }
///     ],
///     "MUET": [
///       { "subject": "MUET", "grade": "Band 3.0" }
///     ]
///   },
///   "qualificationType": "SPM",
///   "results":          [...],
///   "subjectGradeMap":  {...}
/// }
/// ```
///
/// `qualificationType`, `results`, and `subjectGradeMap` are kept for
/// backward compatibility with counsellor / admin queries that pre-date v2.
/// They always reflect the most recently uploaded qualification.
///
/// ### Why [subjectGradeMap] is kept
///
/// [subjectGradeMap] is the denormalised flat form of the primary
/// qualification's results.  Firestore supports dot-notation queries on maps,
/// so counsellor screens can still query grade data field-by-field.
class StudentResultRecord {
  /// Firebase user ID — also the Firestore document ID.
  final String userId;

  /// UTC timestamp of the most recent upload for this student.
  final DateTime updatedAt;

  /// Most recently uploaded qualification type (backward-compat field).
  final String qualificationType;

  /// Results for [qualificationType] (backward-compat field).
  final List<AcademicResultEntry> results;

  /// Flat `subject → grade` map for [qualificationType] (backward-compat field).
  final Map<String, String> subjectGradeMap;

  /// Full multi-qualification map consumed by [RecommendationEngine].
  ///
  /// Keys are qualification type strings (e.g. `"SPM"`, `"STPM"`, `"MUET"`).
  /// Values are the ordered list of subject–grade entries for that qualification.
  ///
  /// A special entry `{ subject: "CGPA", grade: "<double>" }` may be included
  /// to supply CGPA data for Foundation / Diploma routes.
  final Map<String, List<AcademicResultEntry>> qualifications;

  const StudentResultRecord({
    required this.userId,
    required this.updatedAt,
    required this.qualificationType,
    required this.results,
    required this.subjectGradeMap,
    this.qualifications = const {},
  });

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'updatedAt': Timestamp.fromDate(updatedAt),
        // Backward-compat legacy fields (most recent qualification).
        'qualificationType': qualificationType,
        'results': results.map((e) => e.toJson()).toList(),
        'subjectGradeMap': subjectGradeMap,
        // v2 multi-qualification map.
        'qualifications': {
          for (final entry in qualifications.entries)
            entry.key: entry.value.map((e) => e.toJson()).toList(),
        },
      };

  factory StudentResultRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // ── Legacy primary-qualification fields ──────────────────────────────────
    final rawResults = data['results'] as List? ?? [];
    final legacyEntries = rawResults
        .whereType<Map>()
        .map((r) {
          final m = Map<String, dynamic>.from(r);
          return AcademicResultEntry(
            subject: m['subject'] as String? ?? '',
            grade: m['grade'] as String? ?? '',
          );
        })
        .where((e) => e.subject.isNotEmpty)
        .toList();

    final rawMap = data['subjectGradeMap'] as Map? ?? {};
    final subjectGradeMap = Map<String, String>.from(
      rawMap.map((k, v) => MapEntry(k.toString(), v.toString())),
    );

    final legacyType =
        data['qualificationType'] as String? ?? 'SPM';

    // ── v2 qualifications map ────────────────────────────────────────────────
    final rawQuals = data['qualifications'] as Map? ?? {};
    final qualifications = <String, List<AcademicResultEntry>>{};
    for (final entry in rawQuals.entries) {
      final qualType = entry.key as String;
      final rawList = entry.value as List? ?? [];
      qualifications[qualType] = rawList
          .whereType<Map>()
          .map((r) {
            final m = Map<String, dynamic>.from(r);
            return AcademicResultEntry(
              subject: m['subject'] as String? ?? '',
              grade: m['grade'] as String? ?? '',
            );
          })
          .where((e) => e.subject.isNotEmpty)
          .toList();
    }

    // Seed from legacy fields when migrating a v1 document.
    if (qualifications.isEmpty && legacyEntries.isNotEmpty) {
      qualifications[legacyType] = legacyEntries;
    }

    return StudentResultRecord(
      userId: data['userId'] as String? ?? doc.id,
      updatedAt: ((data['updatedAt'] ?? data['uploadedAt']) as Timestamp?)
              ?.toDate() ??
          DateTime.now(),
      qualificationType: legacyType,
      results: legacyEntries,
      subjectGradeMap: subjectGradeMap,
      qualifications: qualifications,
    );
  }

  // ---------------------------------------------------------------------------
  // Engine bridge
  // ---------------------------------------------------------------------------

  /// Returns the full multi-qualification map for [RecommendationEngine].
  ///
  /// Falls back to `{ qualificationType: results }` for v1 documents that
  /// have not yet been migrated to the v2 `qualifications` map.
  ///
  /// ```dart
  /// final engine = RecommendationEngine();
  /// final result = engine.evaluateCourse(course, record.toEngineInput());
  /// ```
  Map<String, List<AcademicResultEntry>> toEngineInput() {
    if (qualifications.isNotEmpty) return Map.unmodifiable(qualifications);
    return {qualificationType: results};
  }

  @override
  String toString() =>
      'StudentResultRecord('
      'userId: "$userId", '
      'qualifications: ${qualifications.keys.join(', ')}'
      ')';
}

// =============================================================================
// Service
// =============================================================================

/// Handles Firestore persistence for student OCR results.
///
/// Firestore collection : `studentResults`
/// Document ID strategy : student [userId] (one document per student)
///
/// A new [saveResults] call fully overwrites the existing document — only the
/// most recent OCR upload is retained.  Historical uploads are not tracked in
/// this collection.
///
/// This service is intentionally dependency-injection-free — callers simply
/// instantiate [StudentResultService] directly.
class StudentResultService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('studentResults');

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Saves [results] for [userId] under [qualificationType].
  ///
  /// Builds [StudentResultRecord.subjectGradeMap] automatically from
  /// [results] so callers never need to construct it manually.
  ///
  /// Uses a get-then-write strategy so that adding a new qualification
  /// (e.g. STPM) does not overwrite a previously saved one (e.g. SPM).
  /// The `qualifications` map is merged at the key level — only
  /// [qualificationType] is replaced; all other keys are preserved.
  ///
  /// Throws a [FirebaseException] on network or permission failure.
  Future<void> saveResults({
    required String userId,
    required String qualificationType,
    required List<AcademicResultEntry> results,
  }) async {
    final subjectGradeMap = {
      for (final entry in results) entry.subject: entry.grade,
    };
    final resultsJson = results.map((e) => e.toJson()).toList();
    final now = Timestamp.fromDate(DateTime.now().toUtc());
    final docRef = _col.doc(userId);

    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      // New document — create with full structure.
      await docRef.set({
        'userId': userId,
        'updatedAt': now,
        'qualificationType': qualificationType,
        'results': resultsJson,
        'subjectGradeMap': subjectGradeMap,
        'qualifications': {qualificationType: resultsJson},
      });
    } else {
      // Existing document — merge only the new qualification key.
      // update() with dot-notation touches exactly one nested key without
      // disturbing other qualification entries already in the map.
      await docRef.update({
        'updatedAt': now,
        'qualificationType': qualificationType,
        'results': resultsJson,
        'subjectGradeMap': subjectGradeMap,
        'qualifications.$qualificationType': resultsJson,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Retrieves the [StudentResultRecord] for [userId].
  ///
  /// Returns `null` when no document exists for the given [userId] (i.e. the
  /// student has not yet uploaded an OCR result).
  ///
  /// Throws a [FirebaseException] on network or permission failure.
  Future<StudentResultRecord?> getResults(String userId) async {
    final doc = await _col.doc(userId).get();
    if (!doc.exists) return null;
    return StudentResultRecord.fromFirestore(doc);
  }
}
