import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/application.dart';
import '../models/offer_letter.dart';
import '../models/payment.dart';
import 'course_service.dart';

/// Handles Firestore persistence for confirmed admission offer letters.
///
/// Firestore collection : `offer_letters`
/// Document ID strategy : auto-generated
class OfferLetterService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('offer_letters');

  final CourseService _courseService = CourseService();

  /// Generates an offer reference number in the format `OL-YYYY-XXXX`.
  Future<String> generateOfferReferenceNo(int year) async {
    final prefix = 'OL-$year-';
    final snapshot = await _col.get();

    final count = snapshot.docs.where((doc) {
      final ref = doc.data()['offerReferenceNo'] as String? ?? '';
      return ref.startsWith(prefix);
    }).length;

    final sequence = (count + 1).toString().padLeft(4, '0');
    return '$prefix$sequence';
  }

  /// Creates an offer letter from an approved payment if one does not already
  /// exist for the linked application.
  Future<OfferLetterModel?> generateFromApprovedPayment(
    PaymentModel payment,
  ) async {
    if (payment.status != PaymentStatus.approved) {
      throw StateError('Offer letters require an approved payment.');
    }

    final existing = await _col
        .where('applicationId', isEqualTo: payment.applicationId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return OfferLetterModel.fromFirestore(existing.docs.first);
    }

    final applicationDoc = await FirebaseFirestore.instance
        .collection('applications')
        .doc(payment.applicationId)
        .get();

    if (!applicationDoc.exists) {
      throw StateError('Application ${payment.applicationId} was not found.');
    }

    final application = ApplicationModel.fromFirestore(applicationDoc);

    if (application.status != ApplicationStatus.approved) {
      throw StateError(
        'Offer letters require an approved application.',
      );
    }

    final course = await _courseService.getCourseById(application.courseId);
    final now = DateTime.now();
    final offerReferenceNo = await generateOfferReferenceNo(now.year);

    final offerLetterData = {
      'studentId': payment.studentId,
      'studentName': payment.studentName,
      'applicationId': payment.applicationId,
      'courseId': application.courseId,
      'courseName': application.courseName,
      'offerReferenceNo': offerReferenceNo,
      'intake': _deriveIntake(application),
      'commencementDate': _deriveCommencementDate(application, now),
      'duration': _deriveDuration(course?.level ?? ''),
      'studyMode': 'Full Time',
      'offerDate': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'paymentTransactionId': payment.transactionId ?? '',
      'creditTransfers':
          application.creditTransfers.map((subject) => subject.toMap()).toList(),
      'generatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _col.add(offerLetterData);
    final created = await docRef.get();
    return OfferLetterModel.fromFirestore(created);
  }

  Stream<List<OfferLetterModel>> getAllOfferLetters() {
    return _col
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OfferLetterModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<OfferLetterModel?> getStudentOfferLetter(String studentId) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return OfferLetterModel.fromFirestore(snapshot.docs.first);
    });
  }

  Future<OfferLetterModel?> getOfferLetterById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return OfferLetterModel.fromFirestore(doc);
  }

  static String _deriveIntake(ApplicationModel application) {
    final remark = application.remark?.trim() ?? '';
    if (remark.isNotEmpty) {
      final intakeMatch = RegExp(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s*(?:\d{4})?\s*Intake)',
        caseSensitive: false,
      ).firstMatch(remark);

      if (intakeMatch != null) {
        return _titleCase(intakeMatch.group(1)!);
      }
    }

    final now = DateTime.now();
    if (now.month <= 6) {
      return 'July ${now.year} Intake';
    }
    return 'January ${now.year + 1} Intake';
  }

  static String _deriveCommencementDate(
    ApplicationModel application,
    DateTime offerDate,
  ) {
    final intake = _deriveIntake(application).toLowerCase();
    final yearMatch = RegExp(r'\d{4}').firstMatch(intake);
    final year = yearMatch != null
        ? int.parse(yearMatch.group(0)!)
        : offerDate.year;

    const monthMap = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    for (final entry in monthMap.entries) {
      if (intake.contains(entry.key)) {
        final date = DateTime(year, entry.value, 15);
        return _formatDate(date);
      }
    }

    final fallback = DateTime(offerDate.year, offerDate.month + 3, 15);
    return _formatDate(fallback);
  }

  static String _deriveDuration(String courseLevel) {
    switch (courseLevel.toLowerCase()) {
      case 'diploma':
        return '2 Years';
      case 'foundation':
        return '1 Year';
      case 'bachelor':
        return '3 Years';
      default:
        return '3 Years';
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
