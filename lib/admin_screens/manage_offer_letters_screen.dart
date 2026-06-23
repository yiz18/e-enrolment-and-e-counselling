import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/offer_letter.dart';
import '../navigation/logout_navigation.dart';
import '../services/offer_letter_service.dart';
import '../student_screens/offer_letter_screen.dart';

/// Admin screen for viewing generated offer letters (read-only).
class ManageOfferLettersScreen extends StatefulWidget {
  const ManageOfferLettersScreen({super.key});

  @override
  State<ManageOfferLettersScreen> createState() =>
      _ManageOfferLettersScreenState();
}

class _ManageOfferLettersScreenState extends State<ManageOfferLettersScreen> {
  final _service = OfferLetterService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Offer Letters'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 768)
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'logout') {
                  logoutToRoleSelection(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.pushNamed(context, '/adminProfile'),
            ),
        ],
      ),
      body: StreamBuilder<List<OfferLetterModel>>(
        stream: _service.getAllOfferLetters(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load offer letters.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final offerLetters = snapshot.data ?? [];
          if (offerLetters.isEmpty) {
            return const Center(
              child: Text(
                'No offer letters generated yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: offerLetters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final offerLetter = offerLetters[index];
              return _OfferLetterCard(
                offerLetter: offerLetter,
                onTap: () => _showDetails(context, offerLetter),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, OfferLetterModel offerLetter) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offer Letter Details'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow(
                  label: 'University',
                  value: AppConfig.universityName,
                ),
                _DetailRow(label: 'Student Name', value: offerLetter.studentName),
                _DetailRow(label: 'Student ID', value: offerLetter.studentId),
                _DetailRow(label: 'Course Name', value: offerLetter.courseName),
                _DetailRow(
                  label: 'Offer Reference No',
                  value: offerLetter.offerReferenceNo,
                ),
                _DetailRow(
                  label: 'Offer Date',
                  value: OfferLetterScreen.formatDate(offerLetter.offerDate),
                ),
                _DetailRow(label: 'Intake', value: offerLetter.intake),
                _DetailRow(
                  label: 'Commencement Date',
                  value: offerLetter.commencementDate,
                ),
                _DetailRow(label: 'Duration', value: offerLetter.duration),
                _DetailRow(label: 'Study Mode', value: offerLetter.studyMode),
                _DetailRow(
                  label: 'Payment Transaction ID',
                  value: offerLetter.paymentTransactionId,
                ),
                if (offerLetter.creditTransfers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Credit Transfer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...offerLetter.creditTransfers.map(
                    (subject) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(subject.displayLine),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _OfferLetterCard extends StatelessWidget {
  const _OfferLetterCard({
    required this.offerLetter,
    required this.onTap,
  });

  final OfferLetterModel offerLetter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      offerLetter.studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Student ID: ${offerLetter.studentId}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                offerLetter.courseName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Ref: ${offerLetter.offerReferenceNo}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Offer Date: ${OfferLetterScreen.formatDate(offerLetter.offerDate)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
