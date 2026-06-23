import 'package:cloud_firestore/cloud_firestore.dart';

/// Counselling appointment lifecycle status stored in Firestore as a string.
enum AppointmentStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  completed('Completed'),
  rescheduled('Rescheduled');

  const AppointmentStatus(this.firestoreValue);

  final String firestoreValue;

  static AppointmentStatus fromFirestore(String? value) {
    return AppointmentStatus.values.firstWhere(
      (s) => s.firestoreValue == value,
      orElse: () => AppointmentStatus.pending,
    );
  }
}

/// A student counselling appointment stored in the `appointments` collection.
///
/// ### Firestore document shape
/// ```json
/// {
///   "studentId":        "abc123",
///   "studentName":      "Jane Doe",
///   "counsellorId":     "def456",
///   "counsellorName":   "Ms Perng Soo Chen",
///   "appointmentDate":  Timestamp(...),
///   "appointmentTime":  "10:00 AM",
///   "mode":             "Online",
///   "reason":           "Academic concerns",
///   "remarks":          null,
///   "status":           "Pending",
///   "createdAt":        Timestamp(...),
///   "updatedAt":        Timestamp(...)
/// }
/// ```
class AppointmentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String counsellorId;
  final String counsellorName;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String mode;
  final String reason;
  final String? remarks;
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppointmentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.counsellorId,
    required this.counsellorName,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.mode,
    required this.reason,
    this.remarks,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Serialises this appointment to a Firestore-compatible map (excludes [id]).
  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'counsellorId': counsellorId,
        'counsellorName': counsellorName,
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'appointmentTime': appointmentTime,
        'mode': mode,
        'reason': reason,
        if (remarks != null) 'remarks': remarks,
        'status': status.firestoreValue,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory AppointmentModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return AppointmentModel(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      counsellorId: map['counsellorId'] as String? ?? '',
      counsellorName: map['counsellorName'] as String? ?? '',
      appointmentDate: (map['appointmentDate'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      appointmentTime: map['appointmentTime'] as String? ?? '',
      mode: map['mode'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      remarks: map['remarks'] as String?,
      status: AppointmentStatus.fromFirestore(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
    );
  }

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    return AppointmentModel.fromMap(
      id: doc.id,
      map: doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  AppointmentModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? counsellorId,
    String? counsellorName,
    DateTime? appointmentDate,
    String? appointmentTime,
    String? mode,
    String? reason,
    String? remarks,
    AppointmentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      counsellorId: counsellorId ?? this.counsellorId,
      counsellorName: counsellorName ?? this.counsellorName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      mode: mode ?? this.mode,
      reason: reason ?? this.reason,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
