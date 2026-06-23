import 'package:e_enrolment_and_e_counselling_appication/data/subject_catalogs.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/academic_result_parser.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/ocr_post_processor.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/subject_corrector.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/subject_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrPostProcessor orphan row merge', () {
    test('merges grade-only row into following subject-only row', () {
      const gradeRow = OcrRow([
        OcrFragment(text: 'C', top: 100, bottom: 120, left: 300, right: 320),
        OcrFragment(
          text: '(KEPUJIAN)',
          top: 100,
          bottom: 120,
          left: 330,
          right: 420,
        ),
      ]);
      const subjectRow = OcrRow([
        OcrFragment(
          text: 'ADDITIONAL MATHEMATICS',
          top: 130,
          bottom: 150,
          left: 50,
          right: 280,
        ),
      ]);

      final refined = OcrPostProcessor.refineRows(
        OcrStructuredResult([gradeRow, subjectRow]),
      );

      expect(refined.rows.length, 1);
      expect(refined.rows.first.text, contains('ADDITIONAL MATHEMATICS'));
      expect(refined.rows.first.text, contains('C'));
    });
  });

  group('SubjectCorrector deterministic language subjects', () {
    const corrector = SubjectCorrector(subjects: kSpmSubjects);

    test('BAHASA INGGERIS maps to Bahasa Inggeris before fuzzy matching', () {
      final result = corrector.correct('BAHASA INGGERIS');
      expect(result.name, 'Bahasa Inggeris');
      expect(result.confidence, 1.0);
      expect(
        SubjectNormalizer.normalize(result.name),
        'English',
      );
    });

    test('BAHASA ARAB maps to Bahasa Arab', () {
      final result = corrector.correct('BAHASA ARAB');
      expect(result.name, 'Bahasa Arab');
    });

    test('BAHASA CINA maps to Bahasa Cina', () {
      final result = corrector.correct('BAHASA CINA');
      expect(result.name, 'Bahasa Cina');
      expect(SubjectNormalizer.normalize(result.name), 'Chinese');
    });
  });

  group('OcrPostProcessor subject consolidation', () {
    test('consolidates split BAHASA INGGERIS without breaking Mathematics row', () {
      const mathRow = OcrRow([
        OcrFragment(
          text: 'MATHEMATICS',
          top: 1408,
          bottom: 1451,
          left: 179,
          right: 402,
        ),
        OcrFragment(text: 'A', top: 1403, bottom: 1424, left: 1296, right: 1317),
        OcrFragment(
          text: '(CEMERLANG',
          top: 1389,
          bottom: 1433,
          left: 1347,
          right: 1517,
        ),
        OcrFragment(
          text: 'TINGGI)',
          top: 1389,
          bottom: 1433,
          left: 1537,
          right: 1656,
        ),
      ]);
      const inggerisRow = OcrRow([
        OcrFragment(text: 'BAHASA', top: 1279, bottom: 1323, left: 180, right: 294),
        OcrFragment(text: 'INGGERIS', top: 1279, bottom: 1323, left: 308, right: 455),
        OcrFragment(text: 'D', top: 1276, bottom: 1297, left: 1292, right: 1313),
      ]);

      final refined = OcrPostProcessor.refineRows(
        OcrStructuredResult([inggerisRow, mathRow]),
      );

      expect(
        refined.rows.any((row) => row.text.contains('BAHASA INGGERIS')),
        isTrue,
      );
      expect(
        refined.rows.any(
          (row) => row.text.contains('MATHEMATICS') && row.text.contains('A'),
        ),
        isTrue,
      );
      expect(refined.rows.any((row) => row.text.contains('MATHEMATICS (CEMERLANG')),
          isFalse);
    });
  });

  group('AcademicResultParser with merged rows', () {
    test('pairs Additional Mathematics with orphan grade row', () {
      const gradeRow = OcrRow([
        OcrFragment(text: 'g', top: 100, bottom: 120, left: 250, right: 260),
        OcrFragment(text: 'C', top: 100, bottom: 120, left: 300, right: 320),
        OcrFragment(
          text: '(KEPUJIAN)',
          top: 100,
          bottom: 120,
          left: 330,
          right: 420,
        ),
      ]);
      const subjectRow = OcrRow([
        OcrFragment(
          text: 'ADDITIONAL MATHEMATICS',
          top: 130,
          bottom: 150,
          left: 50,
          right: 280,
        ),
      ]);

      const corrector = SubjectCorrector(subjects: kSpmSubjects);
      const parser = AcademicResultParser(subjectCorrector: corrector);
      final refined = OcrPostProcessor.refineRows(
        OcrStructuredResult([gradeRow, subjectRow]),
      );
      final parsed = parser.parse(refined);

      expect(
        parsed.results.any(
          (entry) =>
              entry.subject == 'Additional Mathematics' && entry.grade == 'C',
        ),
        isTrue,
      );
    });
  });
}
