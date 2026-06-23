import 'package:flutter/material.dart';

import '../models/report_view_args.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static String _formatListDate(DateTime date) {
    return ReportFormatting.formatLongDate(date);
  }

  Future<void> _openGenerateDialog(BuildContext context) async {
    final args = await showDialog<ReportViewArgs>(
      context: context,
      builder: (context) => const _GenerateReportDialog(),
    );

    if (args == null || !context.mounted) return;

    Navigator.pushNamed(
      context,
      '/reportView',
      arguments: args,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openGenerateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text("Generate New Report"),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: "Search reports...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<EnrolmentReportData>(
                stream: reportService.watchEnrolmentReport(),
                builder: (context, enrolmentSnapshot) {
                  return StreamBuilder<CounsellingReportData>(
                    stream: reportService.watchCounsellingReport(),
                    builder: (context, counsellingSnapshot) {
                      if (enrolmentSnapshot.hasError ||
                          counsellingSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Unable to load reports.\n'
                            '${enrolmentSnapshot.error ?? counsellingSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (enrolmentSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          counsellingSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final generatedDate =
                          _formatListDate(DateTime.now().toLocal());
                      final enrolmentTotal =
                          enrolmentSnapshot.data?.summary.totalApplications ??
                              0;
                      final counsellingTotal = counsellingSnapshot
                              .data?.summary.totalAppointments ??
                          0;

                      final reports = [
                        ReportViewArgs(type: ReportType.enrolment),
                        ReportViewArgs(type: ReportType.counselling),
                      ];

                      return ListView.separated(
                        itemCount: reports.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final args = reports[index];
                          final total = args.type == ReportType.enrolment
                              ? enrolmentTotal
                              : counsellingTotal;
                          final unit = args.type == ReportType.enrolment
                              ? 'application'
                              : 'appointment';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: _buildReportIcon(args.type),
                            title: Text(
                              ReportType.label(args.type),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$generatedDate · $total $unit${total == 1 ? '' : 's'} (all records)',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/reportView',
                                arguments: args,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportIcon(String type) {
    switch (type) {
      case ReportType.enrolment:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Colors.red),
        );

      case ReportType.counselling:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description, color: Colors.blue),
        );

      default:
        return const Icon(Icons.insert_drive_file);
    }
  }
}

class _GenerateReportDialog extends StatefulWidget {
  const _GenerateReportDialog();

  @override
  State<_GenerateReportDialog> createState() => _GenerateReportDialogState();
}

class _GenerateReportDialogState extends State<_GenerateReportDialog> {
  String _selectedType = ReportType.enrolment;
  late DateTime _fromDate;
  late DateTime _toDate;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate({
    required bool isFromDate,
  }) async {
    final initial = isFromDate ? _fromDate : _toDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) return;

    setState(() {
      if (isFromDate) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      _validationMessage = null;
    });
  }

  void _submit() {
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day);

    if (from.isAfter(to)) {
      setState(() {
        _validationMessage = 'From Date must be on or before To Date.';
      });
      return;
    }

    Navigator.pop(
      context,
      ReportViewArgs(
        type: _selectedType,
        fromDate: from,
        toDate: to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate New Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Report Type',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  items: ReportType.all
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(ReportType.label(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedType = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('From Date'),
              subtitle: Text(ReportFormatting.formatLongDate(_fromDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isFromDate: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('To Date'),
              subtitle: Text(ReportFormatting.formatLongDate(_toDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isFromDate: false),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
