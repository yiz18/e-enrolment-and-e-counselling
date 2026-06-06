/// Extracted student identity fields from an SPM result slip.
class StudentInfo {
  /// Student's full name as printed on the certificate (typically all caps).
  final String name;

  /// Malaysian IC number in canonical format: `XXXXXX-XX-XXXX`.
  final String ic;

  /// SPM candidate registration number (e.g. `PC017A124`).
  final String candidateId;

  const StudentInfo({
    required this.name,
    required this.ic,
    required this.candidateId,
  });

  /// Serialises to the `studentInfo` block expected by the recommendation
  /// engine and the application's JSON API.
  Map<String, dynamic> toJson() => {
        'name': name,
        'ic': ic,
        'candidateId': candidateId,
      };

  @override
  String toString() =>
      'StudentInfo(name: "$name", ic: "$ic", candidateId: "$candidateId")';
}
