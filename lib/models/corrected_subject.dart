/// The result of running [SubjectCorrector.correct] on a raw OCR string.
class CorrectedSubject {
  /// Canonical subject name from the dictionary when [isCorrected] is true,
  /// or the original raw input text when no confident match was found.
  final String name;

  /// Best similarity score found in [0.0, 1.0].
  ///
  /// Reflects the closest dictionary match regardless of whether it exceeded
  /// the acceptance threshold. Use this to distinguish a near-miss (e.g.
  /// 0.50) from a genuine no-match (e.g. 0.10).
  final double confidence;

  /// True when [name] was replaced with a dictionary entry.
  ///
  /// False in two cases:
  ///   1. The best match score was below the acceptance threshold.
  ///   2. The OCR text already matched a canonical subject exactly.
  final bool isCorrected;

  /// The original OCR text before any correction was applied.
  final String rawInput;

  const CorrectedSubject({
    required this.name,
    required this.confidence,
    required this.isCorrected,
    required this.rawInput,
  });

  /// Whether the confidence is too low to trust — useful for flagging entries
  /// in the UI for manual review.
  bool get isLowConfidence => confidence < 0.55;

  @override
  String toString() =>
      'CorrectedSubject('
      'name: "$name", '
      'confidence: ${confidence.toStringAsFixed(3)}, '
      'isCorrected: $isCorrected, '
      'raw: "$rawInput"'
      ')';
}
