import 'dart:convert';
import 'dart:io';

import 'package:e_enrolment_and_e_counselling_appication/data/subject_catalogs.dart';
import 'package:e_enrolment_and_e_counselling_appication/models/parsed_academic_result.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/academic_result_parser.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/ocr_post_processor.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/subject_corrector.dart';
import 'package:flutter_test/flutter_test.dart';

const _expectedSubjects = {
  'Bahasa Melayu': 'C',
  'English': 'D',
  'Moral Education': 'C+',
  'History': 'E',
  'Mathematics': 'A',
  'Science': 'C',
  'Additional Mathematics': 'C',
  'Economics': 'E',
  'Chinese': 'B',
};

OcrStructuredResult _loadStructuredResult(String jsonPath) {
  final file = File(jsonPath);
  expect(file.existsSync(), isTrue, reason: 'Missing $jsonPath');

  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final rawRows = decoded['rows'] as List<dynamic>;

  final rows = rawRows.map((rawRow) {
    final fragments = (rawRow['fragments'] as List<dynamic>).map((f) {
      final m = f as Map<String, dynamic>;
      return OcrFragment(
        text: m['text'] as String,
        top: (m['top'] as num).toDouble(),
        bottom: (m['bottom'] as num).toDouble(),
        left: (m['left'] as num).toDouble(),
        right: (m['right'] as num).toDouble(),
      );
    }).toList();
    return OcrRow(fragments);
  }).toList();

  return OcrStructuredResult(rows);
}

ParsedAcademicResult _parse(OcrStructuredResult structured, {required bool refine}) {
  final input = refine ? OcrPostProcessor.refineRows(structured) : structured;
  const corrector = SubjectCorrector(subjects: kSpmSubjects);
  const parser = AcademicResultParser(subjectCorrector: corrector);
  return parser.parse(input);
}

Map<String, String> _resultMap(ParsedAcademicResult parsed) {
  return {for (final entry in parsed.results) entry.subject: entry.grade};
}

List<String> _missingSubjects(Map<String, String> actual) {
  return _expectedSubjects.keys
      .where((subject) => !actual.containsKey(subject))
      .toList();
}

List<String> _incorrectSubjects(Map<String, String> actual) {
  final incorrect = <String>[];
  for (final entry in actual.entries) {
    final expectedGrade = _expectedSubjects[entry.key];
    if (expectedGrade == null || expectedGrade != entry.value) {
      incorrect.add('${entry.key}=${entry.value}');
    }
  }
  return incorrect;
}

void main() {
  test('SPM_YYZ Tesseract POC comparison: current vs improved compatibility', () {
    const jsonPath = 'backend/poc/tesseract_rows_output.json';
    final structured = _loadStructuredResult(jsonPath);

    final current = _parse(structured, refine: false);
    final improved = _parse(structured, refine: true);

    final currentMap = _resultMap(current);
    final improvedMap = _resultMap(improved);

    // ignore: avoid_print
    print('=== CURRENT POC ===');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(current.toJson()));
    // ignore: avoid_print
    print('=== IMPROVED POC ===');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(improved.toJson()));

    // ignore: avoid_print
    print('=== COMPARISON ===');
    // ignore: avoid_print
    print(
      'Name | current=${current.studentInfo?.name} | improved=${improved.studentInfo?.name}',
    );
    // ignore: avoid_print
    print(
      'IC | current=${current.studentInfo?.ic} | improved=${improved.studentInfo?.ic}',
    );
    // ignore: avoid_print
    print(
      'Candidate | current=${current.studentInfo?.candidateId} | improved=${improved.studentInfo?.candidateId}',
    );
    // ignore: avoid_print
    print(
      'Subject count | current=${current.results.length} | improved=${improved.results.length}',
    );
    // ignore: avoid_print
    print('Missing | current=${_missingSubjects(currentMap)}');
    // ignore: avoid_print
    print('Missing | improved=${_missingSubjects(improvedMap)}');
    // ignore: avoid_print
    print('Incorrect | current=${_incorrectSubjects(currentMap)}');
    // ignore: avoid_print
    print('Incorrect | improved=${_incorrectSubjects(improvedMap)}');

    expect(current.hasStudentInfo, isTrue);
    expect(improved.hasStudentInfo, isTrue);
    expect(improved.results.length, greaterThanOrEqualTo(current.results.length));
    expect(
      improvedMap['English'],
      'D',
      reason: 'Bahasa Inggeris should no longer map to Bahasa Arab',
    );
    expect(
      improvedMap.containsKey('Additional Mathematics'),
      isTrue,
      reason: 'Orphan grade row should attach to Additional Mathematics',
    );
    expect(
      improvedMap['Mathematics'],
      'A',
      reason: 'Partial grade descriptions must not break Mathematics pairing',
    );
  });
}
