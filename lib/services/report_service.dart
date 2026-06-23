import '../models/application.dart';
import '../models/appointment.dart';
import '../models/course.dart';
import '../models/report_view_args.dart';
import 'application_service.dart';
import 'appointment_service.dart';
import 'course_service.dart';

/// A single row in the student enrolment report table.
class EnrolmentReportRow {
  const EnrolmentReportRow({
    required this.studentName,
    required this.courseName,
    required this.status,
    required this.appliedAt,
  });

  final String studentName;
  final String courseName;
  final ApplicationStatus status;
  final DateTime appliedAt;
}

/// Aggregated enrolment metrics for the report summary block.
class EnrolmentReportSummary {
  const EnrolmentReportSummary({
    required this.totalApplications,
    required this.approved,
    required this.pending,
    required this.rejected,
  });

  final int totalApplications;
  final int approved;
  final int pending;
  final int rejected;

  Map<String, String> get asLabelMap => {
        'Total Applications': '$totalApplications',
        'Approved': '$approved',
        'Pending': '$pending',
        'Rejected': '$rejected',
      };
}

/// Live enrolment report payload derived from `applications` and `courses`.
class EnrolmentReportData {
  const EnrolmentReportData({
    required this.rows,
    required this.summary,
  });

  final List<EnrolmentReportRow> rows;
  final EnrolmentReportSummary summary;
}

/// A single row in the counselling appointment report table.
class CounsellingReportRow {
  const CounsellingReportRow({
    required this.studentName,
    required this.counsellorName,
    required this.appointmentDate,
    required this.mode,
    required this.status,
  });

  final String studentName;
  final String counsellorName;
  final DateTime appointmentDate;
  final String mode;
  final AppointmentStatus status;
}

/// Aggregated counselling metrics for the report summary block.
class CounsellingReportSummary {
  const CounsellingReportSummary({
    required this.totalAppointments,
    required this.approved,
    required this.pending,
    required this.completed,
    required this.rejected,
  });

  final int totalAppointments;
  final int approved;
  final int pending;
  final int completed;
  final int rejected;

  Map<String, String> get asLabelMap => {
        'Total Appointments': '$totalAppointments',
        'Approved': '$approved',
        'Pending': '$pending',
        'Completed': '$completed',
        'Rejected': '$rejected',
      };
}

/// Live counselling report payload derived from `appointments`.
class CounsellingReportData {
  const CounsellingReportData({
    required this.rows,
    required this.summary,
  });

  final List<CounsellingReportRow> rows;
  final CounsellingReportSummary summary;
}

/// Shared date formatting helpers for report UI and PDF export.
abstract final class ReportFormatting {
  static String formatLongDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]}';
  }

  static String formatPeriod(DateTime? fromDate, DateTime? toDate) {
    if (fromDate == null || toDate == null) {
      return 'All records';
    }
    return '${formatLongDate(fromDate)} - ${formatLongDate(toDate)}';
  }

  static String pdfFileSuffix(DateTime? fromDate, DateTime? toDate) {
    if (fromDate == null || toDate == null) {
      return 'all-records';
    }

    String part(DateTime date) {
      final local = date.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    }

    return '${part(fromDate)}_${part(toDate)}';
  }
}

/// Builds admin report views from Firestore-backed domain services.
class ReportService {
  ReportService({
    ApplicationService? applicationService,
    AppointmentService? appointmentService,
    CourseService? courseService,
  })  : _applicationService = applicationService ?? ApplicationService(),
        _appointmentService = appointmentService ?? AppointmentService(),
        _courseService = courseService ?? CourseService();

  final ApplicationService _applicationService;
  final AppointmentService _appointmentService;
  final CourseService _courseService;

  /// Live student enrolment report: applications enriched with course names.
  Stream<EnrolmentReportData> watchEnrolmentReport({ReportDateRange? range}) {
    return _courseService.getCoursesStream().asyncExpand((courses) {
      final courseById = {for (final course in courses) course.id: course};
      final applicationsStream = range == null
          ? _applicationService.getAllApplications()
          : _applicationService.getApplicationsByDateRange(
              from: range.from,
              to: range.to,
            );

      return applicationsStream.map(
        (applications) => _buildEnrolmentReport(applications, courseById),
      );
    });
  }

  /// Live counselling appointment report from appointments.
  Stream<CounsellingReportData> watchCounsellingReport({ReportDateRange? range}) {
    final appointmentsStream = range == null
        ? _appointmentService.getAllAppointments()
        : _appointmentService.getAppointmentsByDateRange(
            from: range.from,
            to: range.to,
          );

    return appointmentsStream.map(_buildCounsellingReport);
  }

  ReportDateRange? dateRangeFromArgs(ReportViewArgs args) {
    if (!args.hasDateRange) return null;
    return ReportDateRange(from: args.fromDate!, to: args.toDate!);
  }

  EnrolmentReportData _buildEnrolmentReport(
    List<ApplicationModel> applications,
    Map<String, Course> courseById,
  ) {
    var approved = 0;
    var pending = 0;
    var rejected = 0;

    final rows = applications.map((application) {
      switch (application.status) {
        case ApplicationStatus.approved:
          approved++;
        case ApplicationStatus.pending:
          pending++;
        case ApplicationStatus.rejected:
          rejected++;
      }

      final courseName = _resolveCourseName(application, courseById);

      return EnrolmentReportRow(
        studentName: application.studentName,
        courseName: courseName,
        status: application.status,
        appliedAt: application.appliedAt,
      );
    }).toList();

    return EnrolmentReportData(
      rows: rows,
      summary: EnrolmentReportSummary(
        totalApplications: applications.length,
        approved: approved,
        pending: pending,
        rejected: rejected,
      ),
    );
  }

  CounsellingReportData _buildCounsellingReport(
    List<AppointmentModel> appointments,
  ) {
    var approved = 0;
    var pending = 0;
    var completed = 0;
    var rejected = 0;

    final rows = appointments.map((appointment) {
      switch (appointment.status) {
        case AppointmentStatus.approved:
          approved++;
        case AppointmentStatus.pending:
          pending++;
        case AppointmentStatus.completed:
          completed++;
        case AppointmentStatus.rejected:
          rejected++;
        case AppointmentStatus.rescheduled:
          break;
      }

      return CounsellingReportRow(
        studentName: appointment.studentName,
        counsellorName: appointment.counsellorName,
        appointmentDate: appointment.appointmentDate,
        mode: appointment.mode,
        status: appointment.status,
      );
    }).toList();

    return CounsellingReportData(
      rows: rows,
      summary: CounsellingReportSummary(
        totalAppointments: appointments.length,
        approved: approved,
        pending: pending,
        completed: completed,
        rejected: rejected,
      ),
    );
  }

  static String _resolveCourseName(
    ApplicationModel application,
    Map<String, Course> courseById,
  ) {
    final storedName = application.courseName.trim();
    if (storedName.isNotEmpty) return storedName;

    final course = courseById[application.courseId];
    if (course != null && course.name.trim().isNotEmpty) {
      return course.name;
    }

    return application.courseCode.trim().isNotEmpty
        ? application.courseCode
        : '—';
  }
}
