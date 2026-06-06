/// A single subject–grade pair extracted from an OCR result slip, with the
/// subject name fully normalised through the two-stage pipeline:
///
///   1. **[SubjectCorrector]** — fixes OCR character-level noise
///      (e.g. `"BIOLLOGY"` → `"Biologi"`).
///   2. **[SubjectNormalizer]** — maps language/alias differences to the
///      canonical English name stored in Firestore and matched by
///      [RecommendationEngine] (e.g. `"Biologi"` → `"Biology"`,
///      `"Bahasa Inggeris"` → `"English"`).
///
/// [subject] therefore always holds a canonical English name (e.g.
/// `"English"`, `"Additional Mathematics"`), never a raw Malay certificate
/// label.
///
/// [grade] holds the normalised letter grade extracted from the certificate
/// (e.g. `"A"`, `"C+"`, `"B"`). Grade descriptions such as `KEPUJIAN` or
/// `LULUS` are stripped during parsing and are never present here.
class AcademicResultEntry {
  final String subject;
  final String grade;

  const AcademicResultEntry({
    required this.subject,
    required this.grade,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'grade': grade,
      };

  @override
  String toString() =>
      'AcademicResultEntry(subject: "$subject", grade: "$grade")';
}
