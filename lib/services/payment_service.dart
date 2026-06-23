import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/application.dart';
import '../models/payment.dart';
import 'offer_letter_service.dart';

/// Handles Firestore persistence for enrollment fee payments.
///
/// Firestore collection : `payments`
/// Document ID strategy : auto-generated (one document per application cycle)
class PaymentService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('payments');

  final CollectionReference<Map<String, dynamic>> _applicationsCol =
      FirebaseFirestore.instance.collection('applications');

  final OfferLetterService _offerLetterService = OfferLetterService();

  Future<ApplicationModel> _requireApprovedApplication({
    required String studentId,
    required String applicationId,
  }) async {
    final applicationDoc = await _applicationsCol.doc(applicationId).get();
    if (!applicationDoc.exists) {
      throw StateError('Application $applicationId was not found.');
    }

    final application = ApplicationModel.fromFirestore(applicationDoc);

    if (application.userId != studentId) {
      throw StateError(
        'This application does not belong to the signed-in student.',
      );
    }

    if (application.status != ApplicationStatus.approved) {
      throw StateError(
        'Payment is only available after the application is approved.',
      );
    }

    return application;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findPaymentDoc(
    String applicationId,
  ) async {
    final snapshot = await _col
        .where('applicationId', isEqualTo: applicationId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }

  /// Generates a transaction ID in the format `TXN-YYYYMMDD-0001`.
  Future<String> generateTransactionId() async {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'TXN-$datePart-';

    final dayStart = DateTime(now.year, now.month, now.day);
    final snapshot = await _col
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .get();

    final sequence = (snapshot.docs.length + 1).toString().padLeft(4, '0');
    return '$prefix$sequence';
  }

  /// Records a completed mock payment with `status = pending`.
  Future<PaymentModel> submitPayment({
    required String studentId,
    required String studentName,
    required String applicationId,
    required String courseName,
    required double amount,
    required PaymentMethod paymentMethod,
    required String studentReference,
    required String billReference,
  }) async {
    await _requireApprovedApplication(
      studentId: studentId,
      applicationId: applicationId,
    );

    final existingDoc = await _findPaymentDoc(applicationId);
    final transactionId = await generateTransactionId();

    if (existingDoc != null) {
      final existing = PaymentModel.fromFirestore(existingDoc);

      if (existing.status.isAwaitingVerification ||
          existing.status == PaymentStatus.approved) {
        throw StateError(
          'A payment is already in progress for application $applicationId',
        );
      }

      if (existing.status == PaymentStatus.rejected) {
        await existingDoc.reference.update({
          'status': PaymentStatus.pending.firestoreValue,
          'transactionId': transactionId,
          'studentReference': studentReference,
          'billReference': billReference,
          'paymentMethod': paymentMethod.name,
          'initiatedAt': FieldValue.serverTimestamp(),
          'amount': amount,
          'receiptUrl': FieldValue.delete(),
          'remarks': FieldValue.delete(),
          'verifiedBy': FieldValue.delete(),
          'verifiedAt': FieldValue.delete(),
        });

        final updated = await existingDoc.reference.get();
        return PaymentModel.fromFirestore(updated);
      }
    }

    final docRef = await _col.add({
      'studentId': studentId,
      'studentName': studentName,
      'applicationId': applicationId,
      'courseName': courseName,
      'amount': amount,
      'transactionId': transactionId,
      'studentReference': studentReference,
      'billReference': billReference,
      'paymentMethod': paymentMethod.name,
      'status': PaymentStatus.pending.firestoreValue,
      'initiatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final created = await docRef.get();
    return PaymentModel.fromFirestore(created);
  }

  Stream<List<PaymentModel>> getStudentPayments(String studentId) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<PaymentModel>> getAllPayments() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> approvePayment({
    required String paymentId,
    required String verifiedBy,
    String? remarks,
  }) async {
    final paymentDoc = await _col.doc(paymentId).get();
    if (!paymentDoc.exists) {
      throw StateError('Payment $paymentId was not found.');
    }

    final payment = PaymentModel.fromFirestore(paymentDoc);
    if (!payment.status.isAwaitingVerification) {
      throw StateError('Only pending payments can be approved.');
    }

    await _col.doc(paymentId).update({
      'status': PaymentStatus.approved.firestoreValue,
      'verifiedBy': verifiedBy,
      'verifiedAt': FieldValue.serverTimestamp(),
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });

    final updatedDoc = await _col.doc(paymentId).get();
    final approvedPayment = PaymentModel.fromFirestore(updatedDoc);

    await _offerLetterService.generateFromApprovedPayment(approvedPayment);
  }

  Future<void> rejectPayment({
    required String paymentId,
    required String verifiedBy,
    String? remarks,
  }) async {
    await _col.doc(paymentId).update({
      'status': PaymentStatus.rejected.firestoreValue,
      'verifiedBy': verifiedBy,
      'verifiedAt': FieldValue.serverTimestamp(),
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });
  }

  Future<void> updatePaymentRemarks({
    required String paymentId,
    required String remarks,
  }) async {
    await _col.doc(paymentId).update({'remarks': remarks.trim()});
  }
}
