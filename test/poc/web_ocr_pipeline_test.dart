import 'dart:io';

import 'package:e_enrolment_and_e_counselling_appication/data/subject_catalogs.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/academic_result_parser.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/remote_ocr_service.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/subject_corrector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the full web OCR pipeline:
/// POST /ocr JSON → RemoteOcrService.parseResponse → AcademicResultParser
void main() {
  test('web OCR pipeline reaches ParsedAcademicResult with 8 SPM subjects', () {
    const jsonPath = 'backend/poc/tesseract_rows_output.json';
    final file = File(jsonPath);
    expect(file.existsSync(), isTrue, reason: 'Missing $jsonPath');

    final structured = RemoteOcrService.parseResponse(
      file.readAsStringSync(),
    );

    const corrector = SubjectCorrector(subjects: kSpmSubjects);
    const parser = AcademicResultParser(subjectCorrector: corrector);
    final parsed = parser.parse(structured);

    expect(parsed.hasStudentInfo, isTrue);
    expect(parsed.studentInfo?.ic, '011018-07-0829');
    expect(parsed.studentInfo?.candidateId, 'PC017A124');
    expect(parsed.results.length, 8);

    final subjects = {for (final entry in parsed.results) entry.subject: entry.grade};
    expect(subjects['English'], 'D');
    expect(subjects['Mathematics'], 'A');
    expect(subjects['Additional Mathematics'], 'C');
    expect(subjects.containsKey('Chinese'), isFalse);
  });
}
