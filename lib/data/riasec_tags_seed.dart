import '../services/course_service.dart';

/// Approved RIASEC interest tags for each TARUMT degree programme.
///
/// Tags are ordered from strongest to weakest match.
/// Source: RIASEC analysis approved on 2026-06-04.
const Map<String, List<String>> _riasecTagsByCourseName = {
  'Bachelor of Public Relations (Honours)': [
    'Enterprising',
    'Artistic',
    'Social',
  ],
  'Bachelor of Finance and Investment (Honours)': [
    'Enterprising',
    'Conventional',
    'Investigative',
  ],
  'Bachelor of Business Administration (Honours)': [
    'Enterprising',
    'Conventional',
    'Social',
  ],
  'Bachelor of Business (Honours) Accounting and Finance': [
    'Conventional',
    'Enterprising',
    'Investigative',
  ],
  'Bachelor of Business (Honours) International Business Management': [
    'Enterprising',
    'Conventional',
    'Social',
  ],
  'Bachelor in Applied Business Analytics (Honours)': [
    'Investigative',
    'Conventional',
    'Enterprising',
  ],
  'Bachelor in Data Science (Honours)': [
    'Investigative',
    'Conventional',
    'Realistic',
  ],
  'Bachelor in Software Engineering (Honours)': [
    'Investigative',
    'Realistic',
    'Conventional',
  ],
  'Bachelor in Information Technology (Honours) (Software Systems Development)': [
    'Investigative',
    'Realistic',
    'Conventional',
  ],
  'Bachelor of Electronics Engineering Technology with Honours': [
    'Realistic',
    'Investigative',
    'Conventional',
  ],
};

/// Writes the approved RIASEC [interestTags] to each course document in
/// Firestore using a partial `update()` call.
///
/// Only the `interestTags` field is written — `admissionPathways` and all
/// other fields remain completely unchanged.
///
/// Returns a [RiasecSeedResult] describing every course that was updated or
/// not found.
Future<RiasecSeedResult> seedRiasecTags() async {
  final service = CourseService();
  final updated = <String>[];
  final notFound = <String>[];

  for (final entry in _riasecTagsByCourseName.entries) {
    final ok = await service.patchInterestTagsByName(entry.key, entry.value);
    if (ok) {
      updated.add(entry.key);
    } else {
      notFound.add(entry.key);
    }
  }

  return RiasecSeedResult(updated: updated, notFound: notFound);
}

/// Result returned by [seedRiasecTags].
class RiasecSeedResult {
  /// Course names whose `interestTags` were successfully updated.
  final List<String> updated;

  /// Course names for which no Firestore document was found.
  final List<String> notFound;

  const RiasecSeedResult({required this.updated, required this.notFound});

  bool get allUpdated => notFound.isEmpty;

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('=== RIASEC Seed Result ===');
    buf.writeln('Updated  (${updated.length}):');
    for (final n in updated) {
      buf.writeln('  ✓ $n');
    }
    if (notFound.isNotEmpty) {
      buf.writeln('Not found (${notFound.length}):');
      for (final n in notFound) {
        buf.writeln('  ✗ $n');
      }
    }
    return buf.toString();
  }
}
