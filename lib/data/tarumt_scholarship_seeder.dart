import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/scholarship.dart';
import '../services/scholarship_service.dart';

/// Builds the initial TAR UMT Merit Scholarship records for Phase 1 seeding.
List<ScholarshipModel> tarumtMeritScholarships({DateTime? timestamp}) {
  final now = timestamp ?? DateTime.now().toUtc();

  ScholarshipModel build({
    required String title,
    required String category,
    required String description,
    required String eligibilityCriteria,
    required int waiverPercentage,
    required String retentionCriteria,
  }) {
    return ScholarshipModel(
      id: '',
      title: title,
      category: category,
      description: description,
      eligibilityCriteria: eligibilityCriteria,
      waiverPercentage: waiverPercentage,
      retentionCriteria: retentionCriteria,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  const preUniDescription =
      'Awarded to outstanding Malaysian students entering Bachelor Degree '
      'programmes. Candidates who meet the criteria are automatically offered '
      'the Merit Scholarship upon admission (Terms & Conditions apply).';

  const foundationDescription =
      'Awarded to outstanding Malaysian students entering Foundation or '
      'Diploma programmes. Candidates who meet the criteria are automatically '
      'offered the Merit Scholarship upon admission (Terms & Conditions apply).';

  const preUni100Retention =
      'CGPA 3.5000 and above: maintained at 100%\n'
      'CGPA 3.0000 to 3.4999: adjusted down to 50%\n'
      'CGPA below 3.0000: scholarship withdrawn\n'
      'Must obtain straight passes in all courses (including co-curriculum).';

  const preUniLowerRetention =
      'CGPA 3.0000 and above: maintained at current waiver level\n'
      'CGPA below 3.0000: scholarship withdrawn\n'
      'Must obtain straight passes in all courses (including co-curriculum).';

  const foundation100Retention =
      'CGPA 3.5000 and above: maintained at 100%\n'
      'CGPA 3.2500 to 3.4999: adjusted down to 50%\n'
      'CGPA 3.0000 to 3.2499: adjusted down to 25%\n'
      'CGPA below 3.0000: scholarship withdrawn\n'
      'Must obtain straight passes in all courses (including co-curriculum for Diploma).';

  const foundationLowerRetention =
      'CGPA 3.0000 and above: maintained at current waiver level\n'
      'CGPA below 3.0000: scholarship withdrawn\n'
      'Must obtain straight passes in all courses (including co-curriculum for Diploma).';

  return [
    build(
      title: 'Pre-University Merit Scholarship (100%)',
      category: 'Pre-University',
      description: preUniDescription,
      waiverPercentage: 100,
      eligibilityCriteria:
          'STPM / A Level: minimum 3 As\n'
          'UEC: minimum 8 As\n'
          'Canadian Pre-University (CPU): minimum 95% for all subjects (minimum 6 subjects)\n'
          'SAM / WACE / HSC: minimum ATAR 95\n'
          'TAR UMT Diploma / Foundation / Matriculation: CGPA 3.8500 and above\n'
          'Must have obtained straight passes in all prior courses.',
      retentionCriteria: preUni100Retention,
    ),
    build(
      title: 'Pre-University Merit Scholarship (50%)',
      category: 'Pre-University',
      description: preUniDescription,
      waiverPercentage: 50,
      eligibilityCriteria:
          'STPM / A Level: minimum 2 As\n'
          'UEC: 7 As\n'
          'Canadian Pre-University (CPU): minimum 90% for all subjects (minimum 6 subjects)\n'
          'SAM / WACE / HSC: minimum ATAR 90\n'
          'TAR UMT Diploma / Foundation / Matriculation: CGPA 3.7500 and above\n'
          'Must have obtained straight passes in all prior courses.',
      retentionCriteria: preUniLowerRetention,
    ),
    build(
      title: 'Pre-University Merit Scholarship (25%)',
      category: 'Pre-University',
      description: preUniDescription,
      waiverPercentage: 25,
      eligibilityCriteria:
          'STPM / A Level: 1 A\n'
          'UEC: 6 As',
      retentionCriteria: preUniLowerRetention,
    ),
    build(
      title: 'Pre-University Merit Scholarship (20%)',
      category: 'Pre-University',
      description: preUniDescription,
      waiverPercentage: 20,
      eligibilityCriteria: 'UEC: 5 As',
      retentionCriteria: preUniLowerRetention,
    ),
    build(
      title: 'Foundation / Diploma Merit Scholarship (100%)',
      category: 'Foundation / Diploma',
      description: foundationDescription,
      waiverPercentage: 100,
      eligibilityCriteria:
          'SPM: minimum 8 A+ / A\n'
          'O Level: minimum 8 As',
      retentionCriteria: foundation100Retention,
    ),
    build(
      title: 'Foundation / Diploma Merit Scholarship (50%)',
      category: 'Foundation / Diploma',
      description: foundationDescription,
      waiverPercentage: 50,
      eligibilityCriteria: 'SPM: 8 As',
      retentionCriteria: foundationLowerRetention,
    ),
    build(
      title: 'Foundation / Diploma Merit Scholarship (25%)',
      category: 'Foundation / Diploma',
      description: foundationDescription,
      waiverPercentage: 25,
      eligibilityCriteria: 'SPM: 7 As',
      retentionCriteria: foundationLowerRetention,
    ),
    build(
      title: 'Foundation / Diploma Merit Scholarship (20%)',
      category: 'Foundation / Diploma',
      description: foundationDescription,
      waiverPercentage: 20,
      eligibilityCriteria: 'SPM: 6 As',
      retentionCriteria: foundationLowerRetention,
    ),
    build(
      title: 'Foundation / Diploma Merit Scholarship (15%)',
      category: 'Foundation / Diploma',
      description: foundationDescription,
      waiverPercentage: 15,
      eligibilityCriteria: 'SPM: 5 As',
      retentionCriteria: foundationLowerRetention,
    ),
  ];
}

/// Outcome of [seedTarumtScholarships].
class TarumtScholarshipSeedResult {
  final List<String> created;
  final List<String> skipped;

  const TarumtScholarshipSeedResult({
    required this.created,
    required this.skipped,
  });

  bool get allCreated => skipped.isEmpty;
  int get total => created.length + skipped.length;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('=== TAR UMT Scholarship Seed Result ===')
      ..writeln('Created (${created.length}):');
    for (final title in created) {
      buffer.writeln('  ✓ $title');
    }
    if (skipped.isNotEmpty) {
      buffer.writeln('Skipped (${skipped.length}):');
      for (final title in skipped) {
        buffer.writeln('  – $title');
      }
    }
    return buffer.toString();
  }
}

/// Seeds TAR UMT Merit Scholarship records into Firestore.
///
/// Existing records with the same [title] are skipped so the operation is
/// safe to run more than once.
Future<TarumtScholarshipSeedResult> seedTarumtScholarships() async {
  final service = ScholarshipService();
  final col = FirebaseFirestore.instance.collection('scholarships');
  final created = <String>[];
  final skipped = <String>[];

  for (final scholarship in tarumtMeritScholarships()) {
    final existing = await col
        .where('title', isEqualTo: scholarship.title)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      skipped.add(scholarship.title);
    } else {
      await service.addScholarship(scholarship);
      created.add(scholarship.title);
    }
  }

  return TarumtScholarshipSeedResult(created: created, skipped: skipped);
}
