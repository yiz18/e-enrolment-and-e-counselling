import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Simulated university bill payment type codes used in reference generation.
enum SimulatedPaymentType {
  admission('A'),
  tuition('N'),
  parking('P');

  const SimulatedPaymentType(this.code);

  final String code;
}

/// Generates university-style payment references for simulation.
class PaymentReferenceGenerator {
  PaymentReferenceGenerator._();

  static final _random = Random();

  /// Reference 1: `TUC` + [studentId], e.g. `TUC241163320`.
  static String studentReference(String studentId) => 'TUC$studentId';

  /// Reference 2: `YYYYMM` + payment type + 6 random digits, e.g. `202606A845291`.
  static String billReference(SimulatedPaymentType type) {
    final now = DateTime.now();
    final yyyymm =
        '${now.year}${now.month.toString().padLeft(2, '0')}';
    final digits = _random.nextInt(1000000).toString().padLeft(6, '0');
    return '$yyyymm${type.code}$digits';
  }
}

/// Simulated payment methods shown in the payment dialog.
enum PaymentMethod {
  fpx('FPX Online Banking'),
  creditCard('Credit Card'),
  duitNow('DuitNow');

  const PaymentMethod(this.label);

  final String label;

  static PaymentMethod fromFirestore(String? value) {
    return PaymentMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => PaymentMethod.fpx,
    );
  }
}

/// Payment verification status stored in Firestore as a lowercase string.
///
/// [PaymentStatus.initiated] is retained for backward compatibility with older
/// records and is treated as pending verification in the UI.
enum PaymentStatus {
  initiated('initiated'),
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const PaymentStatus(this.firestoreValue);

  final String firestoreValue;

  static PaymentStatus fromFirestore(String? value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.firestoreValue == value,
      orElse: () => PaymentStatus.pending,
    );
  }

  bool get isAwaitingVerification =>
      this == PaymentStatus.pending || this == PaymentStatus.initiated;
}

/// UI-facing payment state including the pre-payment [notStarted] state.
enum PaymentDisplayStatus {
  notStarted,
  pendingVerification,
  approved,
  rejected;

  /// Maps a persisted [PaymentStatus] to its UI display state.
  static PaymentDisplayStatus fromStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.initiated:
      case PaymentStatus.pending:
        return PaymentDisplayStatus.pendingVerification;
      case PaymentStatus.approved:
        return PaymentDisplayStatus.approved;
      case PaymentStatus.rejected:
        return PaymentDisplayStatus.rejected;
    }
  }

  /// Maps a nullable payment record to a UI display state.
  static PaymentDisplayStatus fromPayment(PaymentModel? payment) {
    if (payment == null) return PaymentDisplayStatus.notStarted;
    return fromStatus(payment.status);
  }
}

/// A student's enrollment fee payment stored in the `payments` collection.
class PaymentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String applicationId;
  final String courseName;
  final double amount;
  final String? transactionId;
  final String? studentReference;
  final String? billReference;
  final String? paymentMethod;
  final DateTime? initiatedAt;
  final String? receiptUrl;
  final PaymentStatus status;
  final String? remarks;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.applicationId,
    required this.courseName,
    required this.amount,
    this.transactionId,
    this.studentReference,
    this.billReference,
    this.paymentMethod,
    this.initiatedAt,
    this.receiptUrl,
    required this.status,
    this.remarks,
    this.verifiedBy,
    this.verifiedAt,
    required this.createdAt,
  });

  bool get hasReceipt => receiptUrl != null && receiptUrl!.trim().isNotEmpty;

  PaymentDisplayStatus get displayStatus =>
      PaymentDisplayStatus.fromStatus(status);

  String get paymentMethodLabel {
    if (paymentMethod == null || paymentMethod!.isEmpty) return '—';
    return PaymentMethod.fromFirestore(paymentMethod).label;
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        'applicationId': applicationId,
        'courseName': courseName,
        'amount': amount,
        if (transactionId != null) 'transactionId': transactionId,
        if (studentReference != null) 'studentReference': studentReference,
        if (billReference != null) 'billReference': billReference,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (initiatedAt != null)
          'initiatedAt': Timestamp.fromDate(initiatedAt!),
        if (hasReceipt) 'receiptUrl': receiptUrl,
        'status': status.firestoreValue,
        if (remarks != null) 'remarks': remarks,
        if (verifiedBy != null) 'verifiedBy': verifiedBy,
        if (verifiedAt != null)
          'verifiedAt': Timestamp.fromDate(verifiedAt!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return PaymentModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      applicationId: data['applicationId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      transactionId: data['transactionId'] as String?,
      studentReference: data['studentReference'] as String?,
      billReference: data['billReference'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      initiatedAt: (data['initiatedAt'] as Timestamp?)?.toDate(),
      receiptUrl: data['receiptUrl'] as String?,
      status: PaymentStatus.fromFirestore(data['status'] as String?),
      remarks: data['remarks'] as String?,
      verifiedBy: data['verifiedBy'] as String?,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
    );
  }

  PaymentModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? applicationId,
    String? courseName,
    double? amount,
    String? transactionId,
    String? studentReference,
    String? billReference,
    String? paymentMethod,
    DateTime? initiatedAt,
    String? receiptUrl,
    PaymentStatus? status,
    String? remarks,
    String? verifiedBy,
    DateTime? verifiedAt,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      applicationId: applicationId ?? this.applicationId,
      courseName: courseName ?? this.courseName,
      amount: amount ?? this.amount,
      transactionId: transactionId ?? this.transactionId,
      studentReference: studentReference ?? this.studentReference,
      billReference: billReference ?? this.billReference,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayRemarks {
    final stored = remarks?.trim();
    if (stored != null && stored.isNotEmpty) return stored;

    switch (displayStatus) {
      case PaymentDisplayStatus.pendingVerification:
        return 'Waiting for admin verification.';
      case PaymentDisplayStatus.approved:
        return 'Payment verified. Your enrollment fee has been confirmed.';
      case PaymentDisplayStatus.rejected:
        return 'Payment rejected. Please start the payment process again.';
      case PaymentDisplayStatus.notStarted:
        return '';
    }
  }
}
