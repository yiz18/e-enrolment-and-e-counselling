import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../services/course_service.dart';

// =============================================================================
// Low-level route / condition builders
// =============================================================================

/// Builds a qualification route that only carries a CGPA floor (no subject
/// conditions). Typical for Foundation and Diploma routes.
Map<String, dynamic> _cgpaRoute(double cgpa) => {
      'minimumCgpa': cgpa,
      'minimumRelevantSubjects': null,
      'minimumGrade': null,
      'relevantSubjects': <String>[],
      'conditionGroups': <Map<String, dynamic>>[],
    };

/// Builds a qualification route with optional CGPA, minimum subject count /
/// grade, and an explicit list of condition groups.
Map<String, dynamic> _route({
  double? minimumCgpa,
  int? minimumRelevantSubjects,
  String? minimumGrade,
  List<Map<String, dynamic>> conditionGroups = const [],
}) =>
    {
      'minimumCgpa': minimumCgpa,
      'minimumRelevantSubjects': minimumRelevantSubjects,
      'minimumGrade': minimumGrade,
      'relevantSubjects': <String>[],
      'conditionGroups': conditionGroups,
    };

/// Wraps [conditions] in an AND group — all conditions must be satisfied.
Map<String, dynamic> _andGroup(List<Map<String, dynamic>> conditions) => {
      'operator': 'AND',
      'conditions': conditions,
    };

/// Wraps [conditions] in an OR group — at least one condition must be satisfied.
Map<String, dynamic> _orGroup(List<Map<String, dynamic>> conditions) => {
      'operator': 'OR',
      'conditions': conditions,
    };

/// Shorthand for a single subject condition.
Map<String, dynamic> _c(String qualification, String subject, String grade) => {
      'qualification': qualification,
      'subject': subject,
      'grade': grade,
    };

// =============================================================================
// Admission pathway templates — one per programme group
// =============================================================================
//
// Each template returns a fresh List so the Course constructor can own the
// list without aliasing issues if the same template is reused.

// ---------------------------------------------------------------------------
// Public Relations Group
// Faculty: FCCM | Used by: BPR
// ---------------------------------------------------------------------------
// SPM   : 5 credits including Bahasa Malaysia (Credit) + English (Credit).
// STPM  : CGPA ≥ 2.0, min 2 passes at grade C in any 2 principal subjects.
// A-Lvl : CGPA ≥ 2.0, min 2 passes at grade E in any 2 subjects.
// UEC   : 5 subjects at grade B or above.
// Found : CGPA ≥ 2.00.
// Dip   : CGPA ≥ 2.00.
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _publicRelationsPathway() => [
      {
        'pathwayName': 'Default Pathway',
        'qualificationRoutes': {
          'Foundation': _cgpaRoute(2.0),
          'Diploma': _cgpaRoute(2.0),
          'STPM': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'C',
          ),
          'A-Level': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'E',
          ),
          'UEC': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'B',
          ),
          'SPM': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'Credit',
            conditionGroups: [
              _andGroup([
                _c('SPM', 'Bahasa Malaysia', 'Credit'),
                _c('SPM', 'English', 'Credit'),
              ]),
            ],
          ),
        },
      },
    ];

// ---------------------------------------------------------------------------
// Business Group
// Faculty: FAFB | Used by: BBA, BBIBM
// ---------------------------------------------------------------------------
// SPM   : 5 credits including Bahasa Malaysia (Credit) + English (Credit).
// STPM  : CGPA ≥ 2.0, min 2 passes at grade C.
// A-Lvl : CGPA ≥ 2.0, min 2 passes at grade E.
// UEC   : 5 subjects at grade B or above.
// Found : CGPA ≥ 2.00.
// Dip   : CGPA ≥ 2.00.
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _businessPathway() => [
      {
        'pathwayName': 'Default Pathway',
        'qualificationRoutes': {
          'Foundation': _cgpaRoute(2.0),
          'Diploma': _cgpaRoute(2.0),
          'STPM': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'C',
          ),
          'A-Level': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'E',
          ),
          'UEC': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'B',
          ),
          'SPM': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'Credit',
            conditionGroups: [
              _andGroup([
                _c('SPM', 'Bahasa Malaysia', 'Credit'),
                _c('SPM', 'English', 'Credit'),
              ]),
            ],
          ),
        },
      },
    ];

// ---------------------------------------------------------------------------
// Finance Group
// Faculty: FAFB | Used by: BFI, BBAF
// ---------------------------------------------------------------------------
// SPM   : 5 credits including Mathematics (Credit) + English (Credit).
// STPM  : CGPA ≥ 2.0, min 2 passes; at least one from
//         Mathematics / Accountancy / Economics (grade C).
// A-Lvl : CGPA ≥ 2.0, min 2 passes; at least one from
//         Mathematics / Economics / Accounting (grade E).
// UEC   : 5 subjects at grade B; at least one from
//         Mathematics / Commerce / Economics (grade B).
// Found : CGPA ≥ 2.00.
// Dip   : CGPA ≥ 2.00.
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _financePathway() => [
      {
        'pathwayName': 'Default Pathway',
        'qualificationRoutes': {
          'Foundation': _cgpaRoute(2.0),
          'Diploma': _cgpaRoute(2.0),
          'STPM': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'C',
            conditionGroups: [
              _orGroup([
                _c('STPM', 'Mathematics', 'C'),
                _c('STPM', 'Accountancy', 'C'),
                _c('STPM', 'Economics', 'C'),
              ]),
            ],
          ),
          'A-Level': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'E',
            conditionGroups: [
              _orGroup([
                _c('A-Level', 'Mathematics', 'E'),
                _c('A-Level', 'Economics', 'E'),
                _c('A-Level', 'Accounting', 'E'),
              ]),
            ],
          ),
          'UEC': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'B',
            conditionGroups: [
              _orGroup([
                _c('UEC', 'Mathematics', 'B'),
                _c('UEC', 'Commerce', 'B'),
                _c('UEC', 'Economics', 'B'),
              ]),
            ],
          ),
          'SPM': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'Credit',
            conditionGroups: [
              _andGroup([
                _c('SPM', 'Mathematics', 'Credit'),
                _c('SPM', 'English', 'Credit'),
              ]),
            ],
          ),
        },
      },
    ];

// ---------------------------------------------------------------------------
// Computing Group
// Faculty: FOCS | Used by: BABA, BDS, BSE, BITSSD
// ---------------------------------------------------------------------------
// SPM   : 5 credits including Mathematics (Credit) + English (Pass).
// STPM  : CGPA ≥ 2.0, min 2 passes; Mathematics required at grade C.
// A-Lvl : CGPA ≥ 2.0, min 2 passes; Mathematics required at grade E.
// UEC   : 5 subjects at grade B; Mathematics required at grade B.
// Found : CGPA ≥ 2.00.
// Dip   : CGPA ≥ 2.50.
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _computingPathway() => [
      {
        'pathwayName': 'Default Pathway',
        'qualificationRoutes': {
          'Foundation': _cgpaRoute(2.0),
          'Diploma': _cgpaRoute(2.5),
          'STPM': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'C',
            conditionGroups: [
              _andGroup([
                _c('STPM', 'Mathematics', 'C'),
              ]),
            ],
          ),
          'A-Level': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'E',
            conditionGroups: [
              _andGroup([
                _c('A-Level', 'Mathematics', 'E'),
              ]),
            ],
          ),
          'UEC': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'B',
            conditionGroups: [
              _andGroup([
                _c('UEC', 'Mathematics', 'B'),
              ]),
            ],
          ),
          'SPM': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'Credit',
            conditionGroups: [
              _andGroup([
                _c('SPM', 'Mathematics', 'Credit'),
                _c('SPM', 'English', 'Pass'),
              ]),
            ],
          ),
        },
      },
    ];

// ---------------------------------------------------------------------------
// Engineering Degree Group
// Faculty: FOE | Reserved for future Bachelor of Engineering programmes
// ---------------------------------------------------------------------------
// SPM   : 5 credits including Mathematics (Credit) + Physics (Credit).
// STPM  : CGPA ≥ 2.0, min 2 passes; Mathematics (C) AND Physics/Chemistry (C).
// A-Lvl : CGPA ≥ 2.0, min 2 passes; Mathematics (E) AND Physics/Chemistry (E).
// UEC   : 5 subjects at grade B; Mathematics (B) AND Physics/Chemistry (B).
// Found : CGPA ≥ 2.00.
// Dip   : CGPA ≥ 2.50.
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _engineeringDegreePathway() => [
      {
        'pathwayName': 'Default Pathway',
        'qualificationRoutes': {
          'Foundation': _cgpaRoute(2.0),
          'Diploma': _cgpaRoute(2.5),
          'STPM': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'C',
            conditionGroups: [
              _andGroup([_c('STPM', 'Mathematics', 'C')]),
              _orGroup([
                _c('STPM', 'Physics', 'C'),
                _c('STPM', 'Chemistry', 'C'),
              ]),
            ],
          ),
          'A-Level': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'E',
            conditionGroups: [
              _andGroup([_c('A-Level', 'Mathematics', 'E')]),
              _orGroup([
                _c('A-Level', 'Physics', 'E'),
                _c('A-Level', 'Chemistry', 'E'),
              ]),
            ],
          ),
          'UEC': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'B',
            conditionGroups: [
              _andGroup([_c('UEC', 'Mathematics', 'B')]),
              _orGroup([
                _c('UEC', 'Physics', 'B'),
                _c('UEC', 'Chemistry', 'B'),
              ]),
            ],
          ),
          'SPM': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'Credit',
            conditionGroups: [
              _andGroup([
                _c('SPM', 'Mathematics', 'Credit'),
                _c('SPM', 'Physics', 'Credit'),
                _c('SPM', 'English', 'Pass'),
              ]),
            ],
          ),
        },
      },
    ];

// ---------------------------------------------------------------------------
// Engineering Technology Group
// Faculty: FOE | Used by: BEET
// ---------------------------------------------------------------------------
// SPM   : 5 credits including Mathematics (Credit) +
//         Physics (Credit) OR Additional Mathematics (Credit).
// STPM  : CGPA ≥ 2.0, min 2 passes; Mathematics (C) AND
//         Physics (C) OR Chemistry (C).
// A-Lvl : CGPA ≥ 2.0, min 2 passes; Mathematics (E) AND
//         Physics (E) OR Chemistry (E).
// UEC   : 5 subjects at grade B; Mathematics (B) AND Physics/Chemistry (B).
// Found : CGPA ≥ 2.00.
// Dip   : CGPA ≥ 2.50 (Engineering Technology or related).
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _engineeringTechPathway() => [
      {
        'pathwayName': 'Default Pathway',
        'qualificationRoutes': {
          'Foundation': _cgpaRoute(2.0),
          'Diploma': _cgpaRoute(2.5),
          'STPM': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'C',
            conditionGroups: [
              _andGroup([_c('STPM', 'Mathematics', 'C')]),
              _orGroup([
                _c('STPM', 'Physics', 'C'),
                _c('STPM', 'Chemistry', 'C'),
              ]),
            ],
          ),
          'A-Level': _route(
            minimumCgpa: 2.0,
            minimumRelevantSubjects: 2,
            minimumGrade: 'E',
            conditionGroups: [
              _andGroup([_c('A-Level', 'Mathematics', 'E')]),
              _orGroup([
                _c('A-Level', 'Physics', 'E'),
                _c('A-Level', 'Chemistry', 'E'),
              ]),
            ],
          ),
          'UEC': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'B',
            conditionGroups: [
              _andGroup([_c('UEC', 'Mathematics', 'B')]),
              _orGroup([
                _c('UEC', 'Physics', 'B'),
                _c('UEC', 'Chemistry', 'B'),
              ]),
            ],
          ),
          'SPM': _route(
            minimumRelevantSubjects: 5,
            minimumGrade: 'Credit',
            conditionGroups: [
              _andGroup([
                _c('SPM', 'Mathematics', 'Credit'),
                _c('SPM', 'English', 'Pass'),
              ]),
              _orGroup([
                _c('SPM', 'Physics', 'Credit'),
                _c('SPM', 'Additional Mathematics', 'Credit'),
              ]),
            ],
          ),
        },
      },
    ];

// =============================================================================
// Course catalogue — 10 TARUMT degree programmes
// =============================================================================
//
// interestTags: sourced from approved RIASEC analysis (riasec_tags_seed.dart).
// Seeding them directly here means the RIASEC seeder becomes a no-op for these
// courses; running the RIASEC seeder again later will produce the same values.

List<Course> _tarumtCourses() => [
      // ── Public Relations Group ──────────────────────────────────────────────
      Course(
        id: 'BPR',
        code: 'BPR',
        name: 'Bachelor of Public Relations (Honours)',
        faculty: 'FCCM',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Enterprising', 'Artistic', 'Social'],
        admissionPathways: _publicRelationsPathway(),
      ),

      // ── Finance Group ───────────────────────────────────────────────────────
      Course(
        id: 'BFI',
        code: 'BFI',
        name: 'Bachelor of Finance and Investment (Honours)',
        faculty: 'FAFB',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Enterprising', 'Conventional', 'Investigative'],
        admissionPathways: _financePathway(),
      ),
      Course(
        id: 'BBAF',
        code: 'BBAF',
        name: 'Bachelor of Business (Honours) Accounting and Finance',
        faculty: 'FAFB',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Conventional', 'Enterprising', 'Investigative'],
        admissionPathways: _financePathway(),
      ),

      // ── Business Group ──────────────────────────────────────────────────────
      Course(
        id: 'BBA',
        code: 'BBA',
        name: 'Bachelor of Business Administration (Honours)',
        faculty: 'FAFB',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Enterprising', 'Conventional', 'Social'],
        admissionPathways: _businessPathway(),
      ),
      Course(
        id: 'BBIBM',
        code: 'BBIBM',
        name: 'Bachelor of Business (Honours) International Business Management',
        faculty: 'FAFB',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Enterprising', 'Conventional', 'Social'],
        admissionPathways: _businessPathway(),
      ),

      // ── Computing Group ─────────────────────────────────────────────────────
      Course(
        id: 'BABA',
        code: 'BABA',
        name: 'Bachelor in Applied Business Analytics (Honours)',
        faculty: 'FAFB',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Investigative', 'Conventional', 'Enterprising'],
        admissionPathways: _computingPathway(),
      ),
      Course(
        id: 'BDS',
        code: 'BDS',
        name: 'Bachelor in Data Science (Honours)',
        faculty: 'FOCS',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Investigative', 'Conventional', 'Realistic'],
        admissionPathways: _computingPathway(),
      ),
      Course(
        id: 'BSE',
        code: 'BSE',
        name: 'Bachelor in Software Engineering (Honours)',
        faculty: 'FOCS',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Investigative', 'Realistic', 'Conventional'],
        admissionPathways: _computingPathway(),
      ),
      Course(
        id: 'BITSSD',
        code: 'BITSSD',
        name: 'Bachelor in Information Technology (Honours) (Software Systems Development)',
        faculty: 'FOCS',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Investigative', 'Realistic', 'Conventional'],
        admissionPathways: _computingPathway(),
      ),

      // ── Engineering Technology Group ────────────────────────────────────────
      Course(
        id: 'BEET',
        code: 'BEET',
        name: 'Bachelor of Electronics Engineering Technology with Honours',
        faculty: 'FOE',
        level: 'Bachelor',
        isActive: true,
        interestTags: const ['Realistic', 'Investigative', 'Conventional'],
        admissionPathways: _engineeringTechPathway(),
      ),
    ];

// =============================================================================
// Public seeder entry point
// =============================================================================

/// Seeds the 10 TARUMT degree courses into Firestore.
///
/// For each course:
/// - If a document with the same [Course.code] already exists → **skipped**.
/// - If no document exists → **created** using [CourseService.addCourse].
///
/// Returns a [TarumtSeedResult] describing every outcome.
///
/// **One-time operation.** Run once to populate the `courses` collection.
/// Subsequent runs are safe — existing documents are never overwritten.
Future<TarumtSeedResult> seedTarumtCourses() async {
  final service = CourseService();
  final col = FirebaseFirestore.instance.collection('courses');
  final created = <String>[];
  final skipped = <String>[];

  for (final course in _tarumtCourses()) {
    final doc = await col.doc(course.code).get();
    if (doc.exists) {
      skipped.add(course.name);
    } else {
      await service.addCourse(course);
      created.add(course.name);
    }
  }

  return TarumtSeedResult(created: created, skipped: skipped);
}

// =============================================================================
// Result type
// =============================================================================

/// Outcome of [seedTarumtCourses].
class TarumtSeedResult {
  /// Names of courses that were newly created in Firestore.
  final List<String> created;

  /// Names of courses that already existed and were skipped.
  final List<String> skipped;

  const TarumtSeedResult({
    required this.created,
    required this.skipped,
  });

  bool get allCreated => skipped.isEmpty;
  bool get allSkipped => created.isEmpty;
  int get total => created.length + skipped.length;

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('=== TARUMT Course Seed Result ===');
    buf.writeln('Created  (${created.length}):');
    for (final n in created) {
      buf.writeln('  ✓ $n');
    }
    if (skipped.isNotEmpty) {
      buf.writeln('Skipped  (${skipped.length}):');
      for (final n in skipped) {
        buf.writeln('  – $n');
      }
    }
    return buf.toString();
  }
}

// =============================================================================
// Exported pathway templates (for testing / future reuse)
// =============================================================================

/// Returns the Engineering Degree Group pathway template.
/// Not assigned to any of the 10 seed courses yet — reserved for future
/// Bachelor of Engineering programmes (e.g. Civil, Electrical, Mechanical).
List<Map<String, dynamic>> engineeringDegreePathway() =>
    _engineeringDegreePathway();
