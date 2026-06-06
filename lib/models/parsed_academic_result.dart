import 'academic_result_entry.dart';
import 'student_info.dart';

/// The complete structured output produced by [AcademicResultParser].
///
/// Contains the extracted student identity ([studentInfo]) and the list of
/// corrected subject–grade pairs ([results]).
///
/// [studentInfo] is nullable: if the IC anchor was not found in the OCR
/// output (e.g. the certificate was cropped above the student-info block),
/// the field is `null` and [hasStudentInfo] returns `false`.
class ParsedAcademicResult {
  final StudentInfo? studentInfo;
  final List<AcademicResultEntry> results;

  const ParsedAcademicResult({
    required this.studentInfo,
    required this.results,
  });

  bool get hasStudentInfo => studentInfo != null;
  bool get hasResults => results.isNotEmpty;

  /// Serialises to the JSON format consumed by the recommendation engine:
  ///
  /// ```json
  /// {
  ///   "studentInfo": { "name": "...", "ic": "...", "candidateId": "..." },
  ///   "results": [
  ///     { "subject": "...", "grade": "..." },
  ///     ...
  ///   ]
  /// }
  /// ```
  Map<String, dynamic> toJson() => {
        'studentInfo': studentInfo?.toJson(),
        'results': results.map((r) => r.toJson()).toList(),
      };

  @override
  String toString() =>
      'ParsedAcademicResult('
      'studentInfo: $studentInfo, '
      'results: ${results.length} entries'
      ')';
}
