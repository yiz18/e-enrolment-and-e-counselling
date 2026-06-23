import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/report_view_args.dart';
import '../services/report_service.dart';
import '../utils/report_pdf_generator.dart';

class ReportViewScreen extends StatelessWidget {
  const ReportViewScreen({super.key});

  static ReportViewArgs _parseArgs(Object? arguments) {
    if (arguments is ReportViewArgs) {
      return arguments;
    }
    if (arguments is String) {
      return ReportViewArgs(type: arguments);
    }
    throw ArgumentError('ReportViewScreen requires ReportViewArgs or String.');
  }

  Future<void> _exportEnrolmentPdf({
    required ReportViewArgs args,
    required EnrolmentReportData data,
  }) async {
    final doc = ReportPdfGenerator.buildEnrolmentDocument(
      data: data,
      generatedAt: DateTime.now(),
      fromDate: args.fromDate,
      toDate: args.toDate,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: ReportPdfGenerator.fileName(
        type: ReportType.enrolment,
        fromDate: args.fromDate,
        toDate: args.toDate,
      ),
    );
  }

  Future<void> _exportCounsellingPdf({
    required ReportViewArgs args,
    required CounsellingReportData data,
  }) async {
    final doc = ReportPdfGenerator.buildCounsellingDocument(
      data: data,
      generatedAt: DateTime.now(),
      fromDate: args.fromDate,
      toDate: args.toDate,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: ReportPdfGenerator.fileName(
        type: ReportType.counselling,
        fromDate: args.fromDate,
        toDate: args.toDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = _parseArgs(ModalRoute.of(context)!.settings.arguments);
    final reportService = ReportService();
    final range = reportService.dateRangeFromArgs(args);
    final reportTitle = ReportType.label(args.type);
    final periodLabel =
        ReportFormatting.formatPeriod(args.fromDate, args.toDate);

    if (args.type == ReportType.enrolment) {
      return StreamBuilder<EnrolmentReportData>(
        stream: reportService.watchEnrolmentReport(range: range),
        builder: (context, snapshot) {
          return _buildScaffold(
            reportTitle: reportTitle,
            periodLabel: periodLabel,
            snapshot: snapshot,
            onExport: snapshot.hasData
                ? () => _exportEnrolmentPdf(
                      args: args,
                      data: snapshot.data as EnrolmentReportData,
                    )
                : null,
            buildReport: (data) => _buildEnrolmentReport(
              data: data as EnrolmentReportData,
              periodLabel: periodLabel,
            ),
          );
        },
      );
    }

    return StreamBuilder<CounsellingReportData>(
      stream: reportService.watchCounsellingReport(range: range),
      builder: (context, snapshot) {
        return _buildScaffold(
          reportTitle: reportTitle,
          periodLabel: periodLabel,
          snapshot: snapshot,
          onExport: snapshot.hasData
              ? () => _exportCounsellingPdf(
                    args: args,
                    data: snapshot.data as CounsellingReportData,
                  )
              : null,
          buildReport: (data) => _buildCounsellingReport(
            data: data as CounsellingReportData,
            periodLabel: periodLabel,
          ),
        );
      },
    );
  }

  Widget _buildScaffold({
    required String reportTitle,
    required String periodLabel,
    required AsyncSnapshot<dynamic> snapshot,
    required Future<void> Function()? onExport,
    required Widget Function(dynamic data) buildReport,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(reportTitle),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (onExport != null)
            IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: onExport,
            ),
        ],
      ),
      body: _buildStreamBody(snapshot, buildReport),
      bottomNavigationBar: onExport == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStreamBody(
    AsyncSnapshot<dynamic> snapshot,
    Widget Function(dynamic data) buildReport,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load report.\n${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting ||
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: buildReport(snapshot.data),
    );
  }

  Widget _buildEnrolmentReport({
    required EnrolmentReportData data,
    required String periodLabel,
  }) {
    final tableRows = <List<String>>[
      ['No', 'Student Name', 'Course Name', 'Status', 'Application Date'],
      ...List.generate(data.rows.length, (index) {
        final row = data.rows[index];
        return [
          '${index + 1}',
          row.studentName,
          row.courseName,
          row.status.firestoreValue,
          ReportFormatting.formatShortDate(row.appliedAt),
        ];
      }),
    ];

    return _reportContainer(
      title: 'STUDENT ENROLMENT REPORT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerInfo(periodLabel: periodLabel),
          const SizedBox(height: 16),
          _table(tableRows),
          const SizedBox(height: 20),
          _summary(data.summary.asLabelMap),
        ],
      ),
    );
  }

  Widget _buildCounsellingReport({
    required CounsellingReportData data,
    required String periodLabel,
  }) {
    final tableRows = <List<String>>[
      [
        'No',
        'Student Name',
        'Counsellor Name',
        'Appointment Date',
        'Mode',
        'Status',
      ],
      ...List.generate(data.rows.length, (index) {
        final row = data.rows[index];
        return [
          '${index + 1}',
          row.studentName,
          row.counsellorName,
          ReportFormatting.formatShortDate(row.appointmentDate),
          row.mode,
          row.status.firestoreValue,
        ];
      }),
    ];

    return _reportContainer(
      title: 'COUNSELLING APPOINTMENT REPORT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerInfo(periodLabel: periodLabel),
          const SizedBox(height: 16),
          _table(tableRows),
          const SizedBox(height: 20),
          _summary(data.summary.asLabelMap),
        ],
      ),
    );
  }

  Widget _reportContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 1),
          child,
        ],
      ),
    );
  }

  Widget _headerInfo({required String periodLabel}) {
    final generatedDate =
        ReportFormatting.formatLongDate(DateTime.now().toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SYSTEM NAME : E-Enrolment and E-Counselling System'),
        const Text('GENERATED BY : Admin'),
        Text('PERIOD : $periodLabel'),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('DATE : $generatedDate'),
        ),
      ],
    );
  }

  Widget _table(List<List<String>> rows) {
    final headerOnly = rows.length <= 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(color: Colors.grey.shade400),
          columnWidths: const {},
          children: rows.asMap().entries.map((entry) {
            final isHeader = entry.key == 0;

            return TableRow(
              decoration: BoxDecoration(
                color: isHeader ? Colors.grey.shade300 : Colors.transparent,
              ),
              children: entry.value.map((cell) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    cell,
                    style: TextStyle(
                      fontWeight:
                          isHeader ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
        if (headerOnly)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'No records found.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _summary(Map<String, String> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('${e.key} : ${e.value}'),
        );
      }).toList(),
    );
  }
}
