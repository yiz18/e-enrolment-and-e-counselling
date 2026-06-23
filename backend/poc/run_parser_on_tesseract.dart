import 'dart:convert';
import 'dart:io';

import 'package:e_enrolment_and_e_counselling_appication/data/subject_catalogs.dart';
import 'package:e_enrolment_and_e_counselling_appication/models/parsed_academic_result.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/academic_result_parser.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/ocr_post_processor.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/subject_corrector.dart';

/// One-off POC: feed Tesseract row JSON into the real AcademicResultParser.
/// Run: dart run backend/poc/run_parser_on_tesseract.dart
Future<void> main() async {
  const jsonPath = 'backend/poc/tesseract_rows_output.json';
  final file = File(jsonPath);
  if (!await file.exists()) {
    stderr.writeln('Missing $jsonPath — run export_rows_json.py first.');
    exit(1);
  }

  final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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

  final structured = OcrStructuredResult(rows);
  const corrector = SubjectCorrector(subjects: kSpmSubjects);
  const parser = AcademicResultParser(subjectCorrector: corrector);
  final ParsedAcademicResult parsed = parser.parse(structured);

  print('=== REAL AcademicResultParser OUTPUT ===');
  print(const JsonEncoder.withIndent('  ').convert(parsed.toJson()));
  print('');
  print('hasStudentInfo: ${parsed.hasStudentInfo}');
  print('hasResults: ${parsed.hasResults}');
  print('resultCount: ${parsed.results.length}');
}
