import 'package:cloud_firestore/cloud_firestore.dart';

/// Each admission pathway represents one independent OR branch.
///
/// Structure of a single pathway map:
/// ```
/// {
///   "pathwayName": "Pathway 1",
///   "qualificationRoutes": {
///     "STPM": {
///       "minimumCgpa": null,
///       "minimumRelevantSubjects": 2,
///       "minimumGrade": "C",
///       "relevantSubjects": [],
///       "conditionGroups": [
///         {
///           "operator": "OR",
///           "conditions": [
///             { "qualification": "SPM",    "subject": "Additional Mathematics", "grade": "Credit" },
///             { "qualification": "O-Level","subject": "Mathematics",            "grade": "C"      },
///             { "qualification": "UEC",    "subject": "Mathematics",            "grade": "B"      }
///           ]
///         }
///       ]
///     }
///   }
/// }
/// ```
///
/// Each `conditionGroups` entry carries an `operator` ("AND" | "OR") and a
/// flat list of individual conditions.  Multiple groups within one route are
/// always evaluated with AND semantics between groups.
///
/// The recommendation engine iterates [admissionPathways] and returns `true`
/// as soon as ANY pathway is satisfied — OR semantics across pathways,
/// AND semantics within a pathway's qualification routes.
///
/// **Backward compatibility** — [Course.fromFirestore] silently converts:
/// - Legacy `admissionRequirements: Map` documents → wrapped in a single
///   "Default Pathway" so they display correctly without any database migration.
/// - Legacy `conditions: List` inside a route → wrapped in a single AND group.
/// - Legacy `subjects: Map` inside a route → converted to conditions, then wrapped.
/// - Condition entries missing a `qualification` key → default to `"SPM"`.
class Course {
  /// Firestore document ID. Equals [code] for all courses created via this app.
  final String id;

  final String code;
  final String name;
  final String faculty;
  final String level;
  final bool isActive;

  /// Tags used for future recommendation engine matching.
  final List<String> interestTags;

  /// Ordered list of admission pathways.  Satisfying ANY one pathway makes the
  /// student eligible for the course (OR relationship between pathways).
  ///
  /// Each entry: `{ "pathwayName": String, "qualificationRoutes": Map<String, routeSchema> }`
  final List<Map<String, dynamic>> admissionPathways;

  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.faculty,
    required this.level,
    required this.isActive,
    required this.interestTags,
    required this.admissionPathways,
  });

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Parses a single qualification route map.
  ///
  /// Priority cascade for condition data:
  /// 1. `conditionGroups` present → normalise and pass through (new format).
  /// 2. `conditions` flat list present → wrap in a single AND group (v1 format).
  /// 3. Legacy `subjects` map present → convert to conditions, then wrap.
  /// 4. None of the above → empty conditionGroups list.
  static Map<String, dynamic> _parseRoute(Map rawRoute) {
    final routeData = Map<String, dynamic>.from(rawRoute);

    final List<Map<String, dynamic>> conditionGroups;

    if (routeData.containsKey('conditionGroups') &&
        routeData['conditionGroups'] is List) {
      // ── New format ────────────────────────────────────────────────────────
      conditionGroups = (routeData['conditionGroups'] as List).map((g) {
        final gMap = Map<String, dynamic>.from(g as Map);
        gMap.putIfAbsent('operator', () => 'AND');
        final rawConds = (gMap['conditions'] as List?) ?? [];
        gMap['conditions'] = rawConds.map((c) {
          final cMap = Map<String, dynamic>.from(c as Map);
          cMap.putIfAbsent('qualification', () => 'SPM');
          return cMap;
        }).toList();
        return gMap;
      }).toList();
    } else if (routeData.containsKey('conditions') &&
        routeData['conditions'] is List) {
      // ── v1 flat conditions list → wrap in single AND group ────────────────
      final conditions = (routeData['conditions'] as List).map((c) {
        final cMap = Map<String, dynamic>.from(c as Map);
        cMap.putIfAbsent('qualification', () => 'SPM');
        return cMap;
      }).toList();
      conditionGroups = conditions.isEmpty
          ? []
          : [
              {'operator': 'AND', 'conditions': conditions}
            ];
    } else {
      // ── Legacy subjects map → convert then wrap ───────────────────────────
      final subjects =
          Map<String, dynamic>.from(routeData['subjects'] as Map? ?? {});
      final conditions = subjects.entries
          .map((s) => <String, dynamic>{
                'qualification': 'SPM',
                'subject': s.key,
                'grade': s.value,
              })
          .toList();
      conditionGroups = conditions.isEmpty
          ? []
          : [
              {'operator': 'AND', 'conditions': conditions}
            ];
    }

    return {
      'minimumCgpa': routeData['minimumCgpa'],
      'minimumRelevantSubjects':
          routeData['minimumRelevantSubjects'] as int?,
      'minimumGrade': routeData['minimumGrade'] as String?,
      'relevantSubjects': List<String>.from(
          routeData['relevantSubjects'] as List? ?? []),
      'conditionGroups': conditionGroups,
    };
  }

  /// Deserializes a Firestore [DocumentSnapshot] into a [Course].
  ///
  /// **Backward-compatibility decision tree:**
  /// 1. `admissionPathways` array present → parse as new format directly.
  /// 2. `admissionRequirements` map present → wrap into a single
  ///    "Default Pathway" (no data loss, no migration script needed).
  /// 3. Neither present → empty pathway list.
  factory Course.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final List<Map<String, dynamic>> admissionPathways;

    if (data.containsKey('admissionPathways') &&
        data['admissionPathways'] is List) {
      // ── New format ──────────────────────────────────────────────────────────
      admissionPathways =
          (data['admissionPathways'] as List).map((p) {
        final pathwayData = Map<String, dynamic>.from(p as Map);
        final rawRoutes =
            pathwayData['qualificationRoutes'] as Map? ?? {};

        final qualificationRoutes = <String, dynamic>{};
        for (final entry in rawRoutes.entries) {
          qualificationRoutes[entry.key] =
              _parseRoute(entry.value as Map);
        }

        return <String, dynamic>{
          'pathwayName':
              pathwayData['pathwayName'] as String? ?? 'Default Pathway',
          'qualificationRoutes': qualificationRoutes,
        };
      }).toList();
    } else {
      // ── Legacy format — wrap admissionRequirements in one Default Pathway ──
      final rawReqs = data['admissionRequirements'] as Map? ?? {};
      if (rawReqs.isEmpty) {
        admissionPathways = [];
      } else {
        final qualificationRoutes = <String, dynamic>{};
        for (final entry in rawReqs.entries) {
          qualificationRoutes[entry.key] =
              _parseRoute(entry.value as Map);
        }
        admissionPathways = [
          <String, dynamic>{
            'pathwayName': 'Default Pathway',
            'qualificationRoutes': qualificationRoutes,
          }
        ];
      }
    }

    return Course(
      id: doc.id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? '',
      faculty: data['faculty'] as String? ?? '',
      level: data['level'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      interestTags:
          List<String>.from(data['interestTags'] as List? ?? []),
      admissionPathways: admissionPathways,
    );
  }

  /// Serializes this [Course] to a Firestore-compatible map.
  ///
  /// Always writes `admissionPathways` — never writes `admissionRequirements`.
  /// Because [CourseService] uses `set()` (full replacement), the old
  /// `admissionRequirements` key is removed from the document on next save.
  Map<String, dynamic> toFirestore() => {
        'code': code,
        'name': name,
        'faculty': faculty,
        'level': level,
        'isActive': isActive,
        'interestTags': interestTags,
        'admissionPathways': admissionPathways,
      };

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  Course copyWith({
    String? id,
    String? code,
    String? name,
    String? faculty,
    String? level,
    bool? isActive,
    List<String>? interestTags,
    List<Map<String, dynamic>>? admissionPathways,
  }) {
    return Course(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      faculty: faculty ?? this.faculty,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      interestTags: interestTags ?? this.interestTags,
      admissionPathways: admissionPathways ?? this.admissionPathways,
    );
  }

  // ---------------------------------------------------------------------------
  // Mock dataset — wrapped in a single Default Pathway; used for seeding / dev fallback.
  // ---------------------------------------------------------------------------

  static final List<Course> mockCourses = [
    Course(
      id: 'BCS',
      code: 'BCS',
      name: 'Bachelor of Computer Science',
      faculty: 'FOCS',
      level: 'Bachelor',
      isActive: true,
      interestTags: const ['technology', 'programming', 'software'],
      admissionPathways: [
        {
          'pathwayName': 'Default Pathway',
          'qualificationRoutes': {
            'Foundation': {
              'minimumCgpa': 2.5,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'Diploma': {
              'minimumCgpa': 2.5,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'STPM': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'A-Level': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'SPM': {
              'minimumCgpa': null,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': [
                {
                  'operator': 'AND',
                  'conditions': [
                    {'qualification': 'SPM', 'subject': 'Mathematics', 'grade': 'Credit'},
                    {'qualification': 'SPM', 'subject': 'English', 'grade': 'Pass'},
                  ],
                },
              ],
            },
          },
        },
      ],
    ),

    Course(
      id: 'BIT',
      code: 'BIT',
      name: 'Bachelor of Information Technology',
      faculty: 'FOCS',
      level: 'Bachelor',
      isActive: true,
      interestTags: const ['technology', 'networking', 'systems'],
      admissionPathways: [
        {
          'pathwayName': 'Default Pathway',
          'qualificationRoutes': {
            'Foundation': {
              'minimumCgpa': 2.5,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'Diploma': {
              'minimumCgpa': 2.5,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'STPM': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'SPM': {
              'minimumCgpa': null,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': [
                {
                  'operator': 'AND',
                  'conditions': [
                    {'qualification': 'SPM', 'subject': 'Mathematics', 'grade': 'Credit'},
                    {'qualification': 'SPM', 'subject': 'English', 'grade': 'Pass'},
                  ],
                },
              ],
            },
          },
        },
      ],
    ),

    Course(
      id: 'DAC',
      code: 'DAC',
      name: 'Diploma in Accounting',
      faculty: 'FAFB',
      level: 'Diploma',
      isActive: true,
      interestTags: const ['finance', 'accounting', 'business'],
      admissionPathways: [
        {
          'pathwayName': 'Default Pathway',
          'qualificationRoutes': {
            'STPM': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'SPM': {
              'minimumCgpa': null,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': [
                {
                  'operator': 'AND',
                  'conditions': [
                    {'qualification': 'SPM', 'subject': 'Mathematics', 'grade': 'Credit'},
                    {'qualification': 'SPM', 'subject': 'English', 'grade': 'Pass'},
                    {'qualification': 'SPM', 'subject': 'Accounting', 'grade': 'Credit'},
                  ],
                },
              ],
            },
          },
        },
      ],
    ),

    Course(
      id: 'BBM',
      code: 'BBM',
      name: 'Bachelor of Business Management',
      faculty: 'FAFB',
      level: 'Bachelor',
      isActive: true,
      interestTags: const ['business', 'management', 'entrepreneurship'],
      admissionPathways: [
        {
          'pathwayName': 'Default Pathway',
          'qualificationRoutes': {
            'Foundation': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'Diploma': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'STPM': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'SPM': {
              'minimumCgpa': null,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': [
                {
                  'operator': 'AND',
                  'conditions': [
                    {'qualification': 'SPM', 'subject': 'Mathematics', 'grade': 'Pass'},
                    {'qualification': 'SPM', 'subject': 'English', 'grade': 'Credit'},
                  ],
                },
              ],
            },
          },
        },
      ],
    ),

    Course(
      id: 'DCE',
      code: 'DCE',
      name: 'Diploma in Civil Engineering',
      faculty: 'FOE',
      level: 'Diploma',
      isActive: false,
      interestTags: const ['engineering', 'construction', 'infrastructure'],
      admissionPathways: [
        {
          'pathwayName': 'Default Pathway',
          'qualificationRoutes': {
            'STPM': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'SPM': {
              'minimumCgpa': null,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': [
                {
                  'operator': 'AND',
                  'conditions': [
                    {'qualification': 'SPM', 'subject': 'Mathematics', 'grade': 'Credit'},
                    {'qualification': 'SPM', 'subject': 'Physics', 'grade': 'Pass'},
                    {'qualification': 'SPM', 'subject': 'English', 'grade': 'Pass'},
                  ],
                },
              ],
            },
          },
        },
      ],
    ),

    Course(
      id: 'BME',
      code: 'BME',
      name: 'Bachelor of Mechanical Engineering',
      faculty: 'FOE',
      level: 'Bachelor',
      isActive: true,
      interestTags: const ['engineering', 'mechanics', 'design'],
      admissionPathways: [
        {
          'pathwayName': 'Default Pathway',
          'qualificationRoutes': {
            'Foundation': {
              'minimumCgpa': 2.5,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'Diploma': {
              'minimumCgpa': 2.5,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'STPM': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'A-Level': {
              'minimumCgpa': 2.0,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': <Map<String, dynamic>>[],
            },
            'SPM': {
              'minimumCgpa': null,
              'minimumRelevantSubjects': null,
              'minimumGrade': null,
              'relevantSubjects': <String>[],
              'conditionGroups': [
                {
                  'operator': 'AND',
                  'conditions': [
                    {'qualification': 'SPM', 'subject': 'Mathematics', 'grade': 'Credit'},
                    {'qualification': 'SPM', 'subject': 'Physics', 'grade': 'Credit'},
                    {'qualification': 'SPM', 'subject': 'English', 'grade': 'Pass'},
                  ],
                },
              ],
            },
          },
        },
      ],
    ),
  ];
}
