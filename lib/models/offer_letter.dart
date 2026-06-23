import 'package:cloud_firestore/cloud_firestore.dart';

import 'credit_transfer_subject.dart';

/// A confirmed admission offer letter stored in the `offer_letters` collection.
///
/// Generated automatically when an admin approves a student's payment after
/// the application has already been approved.
class OfferLetterModel {
  final String id;
  final String studentId;
  final String studentName;
  final String applicationId;
  final String courseId;
  final String courseName;
  final String offerReferenceNo;
  final String intake;
  final String commencementDate;
  final String duration;
  final String studyMode;
  final DateTime offerDate;
  final String paymentTransactionId;
  final List<CreditTransferSubject> creditTransfers;
  final DateTime generatedAt;

  const OfferLetterModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.applicationId,
    required this.courseId,
    required this.courseName,
    required this.offerReferenceNo,
    required this.intake,
    required this.commencementDate,
    required this.duration,
    required this.studyMode,
    required this.offerDate,
    required this.paymentTransactionId,
    required this.creditTransfers,
    required this.generatedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        'applicationId': applicationId,
        'courseId': courseId,
        'courseName': courseName,
        'offerReferenceNo': offerReferenceNo,
        'intake': intake,
        'commencementDate': commencementDate,
        'duration': duration,
        'studyMode': studyMode,
        'offerDate': Timestamp.fromDate(offerDate),
        'paymentTransactionId': paymentTransactionId,
        'creditTransfers':
            creditTransfers.map((subject) => subject.toMap()).toList(),
        'generatedAt': Timestamp.fromDate(generatedAt),
      };

  factory OfferLetterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return OfferLetterModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      applicationId: data['applicationId'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      offerReferenceNo: data['offerReferenceNo'] as String? ?? '',
      intake: data['intake'] as String? ?? '',
      commencementDate: data['commencementDate'] as String? ?? '',
      duration: data['duration'] as String? ?? '',
      studyMode: data['studyMode'] as String? ?? '',
      offerDate:
          (data['offerDate'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      paymentTransactionId: data['paymentTransactionId'] as String? ?? '',
      creditTransfers: creditTransfersFromFirestore(
        data['creditTransfers'] as List<dynamic>?,
      ),
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
    );
  }

  OfferLetterModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? applicationId,
    String? courseId,
    String? courseName,
    String? offerReferenceNo,
    String? intake,
    String? commencementDate,
    String? duration,
    String? studyMode,
    DateTime? offerDate,
    String? paymentTransactionId,
    List<CreditTransferSubject>? creditTransfers,
    DateTime? generatedAt,
  }) {
    return OfferLetterModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      applicationId: applicationId ?? this.applicationId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      offerReferenceNo: offerReferenceNo ?? this.offerReferenceNo,
      intake: intake ?? this.intake,
      commencementDate: commencementDate ?? this.commencementDate,
      duration: duration ?? this.duration,
      studyMode: studyMode ?? this.studyMode,
      offerDate: offerDate ?? this.offerDate,
      paymentTransactionId:
          paymentTransactionId ?? this.paymentTransactionId,
      creditTransfers: creditTransfers ?? this.creditTransfers,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
