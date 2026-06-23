/// A subject credited to a student via credit transfer, stored on the
/// application document and copied into the offer letter at generation time.
class CreditTransferSubject {
  final String subjectCode;
  final String subjectName;
  final int creditHours;

  const CreditTransferSubject({
    required this.subjectCode,
    required this.subjectName,
    required this.creditHours,
  });

  Map<String, dynamic> toMap() => {
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'creditHours': creditHours,
      };

  factory CreditTransferSubject.fromMap(Map<String, dynamic> map) {
    return CreditTransferSubject(
      subjectCode: map['subjectCode'] as String? ?? '',
      subjectName: map['subjectName'] as String? ?? '',
      creditHours: (map['creditHours'] as num?)?.toInt() ?? 0,
    );
  }

  CreditTransferSubject copyWith({
    String? subjectCode,
    String? subjectName,
    int? creditHours,
  }) {
    return CreditTransferSubject(
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      creditHours: creditHours ?? this.creditHours,
    );
  }

  /// Display format: `BACS1013 - Problem Solving and Programming (3)`.
  String get displayLine =>
      '$subjectCode - $subjectName ($creditHours)';
}

List<CreditTransferSubject> creditTransfersFromFirestore(
  List<dynamic>? raw,
) {
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .map((item) =>
          CreditTransferSubject.fromMap(Map<String, dynamic>.from(item as Map)))
      .toList();
}
