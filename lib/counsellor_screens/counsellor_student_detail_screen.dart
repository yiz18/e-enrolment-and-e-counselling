import 'package:flutter/material.dart';

import '../models/application.dart';
import '../models/appointment.dart';
import '../models/student_document.dart';
import '../models/student_interest.dart';
import '../services/application_service.dart';
import '../services/appointment_service.dart';
import '../services/student_document_query_service.dart';
import '../services/student_interest_service.dart';
import '../services/student_result_service.dart';
import '../widgets/application_status_chip.dart';
import '../widgets/appointment_status_chip.dart';
import '../widgets/document_image_preview.dart';

/// Route arguments for [CounsellorStudentDetailScreen].
class CounsellorStudentDetailArgs {
  final String studentId;
  final String studentName;

  const CounsellorStudentDetailArgs({
    required this.studentId,
    required this.studentName,
  });
}

const Map<String, String> _riasecLabels = {
  'R': 'Realistic — hands-on, practical careers',
  'I': 'Investigative — analytical, research-oriented careers',
  'A': 'Artistic — creative, design-oriented careers',
  'S': 'Social — helping, teaching, counselling careers',
  'E': 'Enterprising — leadership, business careers',
  'C': 'Conventional — administrative, organisational careers',
};

class CounsellorStudentDetailScreen extends StatefulWidget {
  const CounsellorStudentDetailScreen({super.key});

  @override
  State<CounsellorStudentDetailScreen> createState() =>
      _CounsellorStudentDetailScreenState();
}

class _CounsellorStudentDetailScreenState
    extends State<CounsellorStudentDetailScreen> {
  final _resultService = StudentResultService();
  final _interestService = StudentInterestService();
  final _documentService = StudentDocumentQueryService();
  final _applicationService = ApplicationService();
  final _appointmentService = AppointmentService();

  CounsellorStudentDetailArgs? _args;
  bool _loading = true;
  String? _error;
  StudentResultRecord? _results;
  StudentInterest? _interests;
  StudentDocumentModel? _documents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args ??=
        ModalRoute.of(context)?.settings.arguments as CounsellorStudentDetailArgs?;
    if (_loading && _args != null && _error == null) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final args = _args;
    if (args == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _resultService.getResults(args.studentId),
        _interestService.getInterests(args.studentId),
        _documentService.getStudentDocuments(args.studentId),
      ]);

      if (!mounted) return;
      setState(() {
        _results = results[0] as StudentResultRecord?;
        _interests = results[1] as StudentInterest?;
        _documents = results[2] as StudentDocumentModel?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load student profile.\n$e';
        _loading = false;
      });
    }
  }

  String? _extractCgpa(StudentResultRecord? record) {
    if (record == null) return null;

    for (final entries in record.qualifications.values) {
      for (final entry in entries) {
        if (entry.subject.toUpperCase() == 'CGPA' && entry.grade.isNotEmpty) {
          return entry.grade;
        }
      }
    }

    for (final entry in record.results) {
      if (entry.subject.toUpperCase() == 'CGPA' && entry.grade.isNotEmpty) {
        return entry.grade;
      }
    }

    return null;
  }

  String? _academicRoute(StudentResultRecord? record) {
    if (record == null) return null;
    if (record.qualifications.isNotEmpty) {
      return record.qualifications.keys.join(', ');
    }
    return record.qualificationType.isNotEmpty ? record.qualificationType : null;
  }

  List<String> _careerAreas(StudentInterest? interest) {
    if (interest == null || interest.riasecCodes.isEmpty) return const [];
    return interest.riasecCodes
        .map((code) => _riasecLabels[code] ?? code)
        .toList();
  }

  static String _formatAppointmentDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;

    if (args == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Student Profile'),
          backgroundColor: Colors.blueAccent,
        ),
        body: const Center(child: Text('Student not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(args.studentName),
        backgroundColor: Colors.blueAccent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAcademicSection(),
                        const SizedBox(height: 24),
                        _buildInterestSection(),
                        const SizedBox(height: 24),
                        _buildApplicationsSection(args.studentId),
                        const SizedBox(height: 24),
                        _buildAppointmentHistorySection(args.studentId),
                        const SizedBox(height: 24),
                        _buildDocumentsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildAcademicSection() {
    final results = _results;
    final cgpa = _extractCgpa(results);
    final route = _academicRoute(results);

    return _SectionCard(
      title: 'Academic Results',
      child: results == null
          ? _emptyText('No academic results uploaded.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('CGPA', cgpa ?? 'Not available'),
                _detailRow('Academic Route', route ?? 'Not available'),
                const SizedBox(height: 12),
                const Text(
                  'Uploaded Result Records',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (results.qualifications.isEmpty && results.results.isEmpty)
                  _emptyText('No subject records found.')
                else
                  ..._buildQualificationBlocks(results),
              ],
            ),
    );
  }

  List<Widget> _buildQualificationBlocks(StudentResultRecord results) {
    final blocks = <Widget>[];
    final qualifications = results.qualifications.isNotEmpty
        ? results.qualifications
        : {results.qualificationType: results.results};

    for (final entry in qualifications.entries) {
      if (entry.value.isEmpty) continue;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 4),
              ...entry.value.map(
                (result) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${result.subject}: ${result.grade}'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return blocks;
  }

  Widget _buildInterestSection() {
    final interest = _interests;
    final careerAreas = _careerAreas(interest);

    return _SectionCard(
      title: 'Interest Profile',
      child: interest == null || !interest.isComplete
          ? _emptyText('No RIASEC interest profile found.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  'Top 3 RIASEC Interests',
                  interest.riasecCodes.join(' • '),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recommended Career Areas',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (careerAreas.isEmpty)
                  _emptyText('No career area mapping available.')
                else
                  ...careerAreas.map(
                    (area) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $area'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildApplicationsSection(String studentId) {
    return _SectionCard(
      title: 'Applications',
      child: StreamBuilder<List<ApplicationModel>>(
        stream: _applicationService.getStudentApplications(studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load applications.\n${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            );
          }

          final applications = snapshot.data ?? [];
          if (applications.isEmpty) {
            return _emptyText('No course applications found.');
          }

          return Column(
            children: applications.map((application) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.courseName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        application.courseCode,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          ApplicationStatusChip(status: application.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _detailRow('Remarks', application.displayRemark),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentHistorySection(String studentId) {
    return _SectionCard(
      title: 'Counselling Appointment History',
      child: StreamBuilder<List<AppointmentModel>>(
        stream: _appointmentService.watchAppointmentsByStudent(studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load appointment history.\n${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            );
          }

          final appointments = snapshot.data ?? [];
          if (appointments.isEmpty) {
            return _emptyText('No counselling appointments found.');
          }

          return Column(
            children: appointments.map((appointment) {
              final formattedDate =
                  _formatAppointmentDate(appointment.appointmentDate.toLocal());

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    '$formattedDate • ${appointment.appointmentTime}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Reason: ${appointment.reason}'),
                      Text('Mode: ${appointment.mode}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(fontSize: 12),
                          ),
                          AppointmentStatusChip(status: appointment.status),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/counsellingHistoryDetail',
                      arguments: appointment,
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final documents = _documents;
    const displayTypes = [
      StudentDocumentType.spmCertificate,
      StudentDocumentType.diplomaCertificate,
      StudentDocumentType.diplomaTranscript,
      StudentDocumentType.otherSupportingDocuments,
    ];

    return _SectionCard(
      title: 'Uploaded Documents',
      child: documents == null ||
              !displayTypes.any((type) => documents.urlsForType(type).isNotEmpty)
          ? _emptyText('No documents uploaded.')
          : Column(
              children: displayTypes.map((type) {
                final urls = documents.urlsForType(type);
                if (urls.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${type.label} (${urls.length} file${urls.length == 1 ? '' : 's'})',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton(
                        onPressed: () => DocumentImagePreview.showFilesSheet(
                          context,
                          title: type.label,
                          urls: urls,
                        ),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _emptyText(String message) {
    return Text(
      message,
      style: TextStyle(color: Colors.grey.shade600),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
