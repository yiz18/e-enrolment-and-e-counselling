import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../config/app_config.dart';
import '../models/offer_letter.dart';
import '../services/offer_letter_service.dart';
import '../utils/offer_letter_pdf_generator.dart';

/// Displays the student's confirmed admission offer letter after payment
/// verification. The letter is generated automatically by the system.
class OfferLetterScreen extends StatelessWidget {
  const OfferLetterScreen({super.key});

  static String formatDate(DateTime date) {
    return OfferLetterPdfGenerator.formatDate(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final service = OfferLetterService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Offer Letter'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view your offer letter.'))
          : StreamBuilder<OfferLetterModel?>(
              stream: service.getStudentOfferLetter(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load offer letter.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final offerLetter = snapshot.data;
                if (offerLetter == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Your offer letter will appear here after your '
                        'application is approved and your payment has been '
                        'verified by the administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _OfferLetterDocument(offerLetter: offerLetter),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadPdf(offerLetter),
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _downloadPdf(OfferLetterModel offerLetter) async {
    final doc = OfferLetterPdfGenerator.buildDocument(offerLetter);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: '${offerLetter.offerReferenceNo}.pdf',
    );
  }
}

class _OfferLetterDocument extends StatelessWidget {
  const _OfferLetterDocument({required this.offerLetter});

  final OfferLetterModel offerLetter;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIRMED OFFER OF ADMISSION',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppConfig.universityName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(
            label: 'Offer Reference No',
            value: offerLetter.offerReferenceNo,
          ),
          _InfoRow(
            label: 'Offer Date',
            value: OfferLetterScreen.formatDate(offerLetter.offerDate),
          ),
          const SizedBox(height: 20),
          _InfoRow(
            label: 'Student Name',
            value: offerLetter.studentName,
            boldValue: true,
          ),
          _InfoRow(label: 'Student ID', value: offerLetter.studentId),
          const SizedBox(height: 20),
          const Text(
            'Course Information',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offerLetter.courseName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Intake: ${offerLetter.intake}'),
                Text('Commencement Date: ${offerLetter.commencementDate}'),
                Text('Duration: ${offerLetter.duration}'),
                Text('Study Mode: ${offerLetter.studyMode}'),
              ],
            ),
          ),
          if (offerLetter.creditTransfers.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Credit Transfer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...offerLetter.creditTransfers.map(
              (subject) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(subject.displayLine),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Confirmation Statement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          const Text('Congratulations.'),
          const SizedBox(height: 8),
          const Text(
            'We are pleased to inform you that your application and '
            'enrollment payment have been successfully verified.',
          ),
          const SizedBox(height: 8),
          const Text(
            'You have been offered admission into the programme stated above.',
          ),
          const SizedBox(height: 8),
          const Text(
            'This offer letter is issued upon successful application '
            'approval and payment verification.',
          ),
          const SizedBox(height: 24),
          const Text('Admissions Office'),
          Text(AppConfig.universityName),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.boldValue = false,
  });

  final String label;
  final String value;
  final bool boldValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: boldValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
