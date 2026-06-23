import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../models/offer_letter.dart';

/// Builds a PDF document that mirrors the student offer letter screen.
class OfferLetterPdfGenerator {
  OfferLetterPdfGenerator._();

  static String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static pw.Document buildDocument(OfferLetterModel offerLetter) {
    final doc = pw.Document();
    final offerDate = formatDate(offerLetter.offerDate.toLocal());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CONFIRMED OFFER OF ADMISSION',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                AppConfig.universityName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text('Offer Reference No: ${offerLetter.offerReferenceNo}'),
              pw.Text('Offer Date: $offerDate'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Student Name: ${offerLetter.studentName}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Student ID: ${offerLetter.studentId}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Course Information',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      offerLetter.courseName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Intake: ${offerLetter.intake}'),
                    pw.Text(
                      'Commencement Date: ${offerLetter.commencementDate}',
                    ),
                    pw.Text('Duration: ${offerLetter.duration}'),
                    pw.Text('Study Mode: ${offerLetter.studyMode}'),
                  ],
                ),
              ),
              if (offerLetter.creditTransfers.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Credit Transfer',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                ...offerLetter.creditTransfers.map(
                  (subject) => pw.Text(subject.displayLine),
                ),
              ],
              pw.SizedBox(height: 24),
              pw.Text(
                'Confirmation Statement',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Congratulations.'),
              pw.SizedBox(height: 6),
              pw.Text(
                'We are pleased to inform you that your application and '
                'enrollment payment have been successfully verified.',
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'You have been offered admission into the programme stated above.',
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'This offer letter is issued upon successful application '
                'approval and payment verification.',
              ),
              pw.SizedBox(height: 24),
              pw.Text('Admissions Office'),
              pw.Text(AppConfig.universityName),
            ],
          );
        },
      ),
    );

    return doc;
  }
}
