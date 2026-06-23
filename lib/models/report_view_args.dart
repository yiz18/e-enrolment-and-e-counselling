/// Navigation arguments for [ReportViewScreen].
class ReportViewArgs {
  const ReportViewArgs({
    required this.type,
    this.fromDate,
    this.toDate,
  });

  /// Report type: [ReportType.enrolment] or [ReportType.counselling].
  final String type;

  final DateTime? fromDate;
  final DateTime? toDate;

  bool get hasDateRange => fromDate != null && toDate != null;

  ReportViewArgs copyWith({
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return ReportViewArgs(
      type: type ?? this.type,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

/// Known admin report type identifiers.
abstract final class ReportType {
  static const String enrolment = 'enrolment';
  static const String counselling = 'counselling';

  static const List<String> all = [enrolment, counselling];

  static String label(String type) {
    switch (type) {
      case enrolment:
        return 'Student Enrolment Report';
      case counselling:
        return 'Counselling Appointment Report';
      default:
        return type;
    }
  }
}

/// Inclusive calendar date range for Firestore report queries.
class ReportDateRange {
  const ReportDateRange({
    required this.from,
    required this.to,
  });

  final DateTime from;
  final DateTime to;

  /// Normalised inclusive start at local midnight.
  DateTime get startInclusive =>
      DateTime(from.year, from.month, from.day);

  /// Exclusive upper bound at the start of the day after [to].
  DateTime get endExclusive =>
      DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
}
