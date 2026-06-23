import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';

/// Handles Firestore persistence for student counselling appointments.
///
/// Firestore collection : `appointments`
/// Document ID strategy : auto-generated (one document per appointment)
///
/// This service is intentionally dependency-injection-free — callers simply
/// instantiate [AppointmentService] directly, consistent with
/// [ApplicationService] and [StudentInterestService].
class AppointmentService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('appointments');

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Creates a new appointment with `status = Pending`.
  ///
  /// Returns the auto-generated Firestore document ID.
  ///
  /// Throws a [FirebaseException] on network or permission failure.
  Future<String> createAppointment({
    required String studentId,
    required String studentName,
    required String counsellorId,
    required String counsellorName,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String mode,
    required String reason,
    String? remarks,
  }) async {
    final docRef = _col.doc();

    await docRef.set({
      'studentId': studentId,
      'studentName': studentName,
      'counsellorId': counsellorId,
      'counsellorName': counsellorName,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'appointmentTime': appointmentTime,
      'mode': mode,
      'reason': reason,
      if (remarks != null) 'remarks': remarks,
      'status': AppointmentStatus.pending.firestoreValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Updates the lifecycle [status] of the appointment at [appointmentId].
  Future<void> updateStatus({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    await _col.doc(appointmentId).update({
      'status': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Persists counsellor [remarks] for the appointment at [appointmentId].
  Future<void> updateRemarks({
    required String appointmentId,
    required String remarks,
  }) async {
    await _col.doc(appointmentId).update({
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes the appointment at [appointmentId].
  Future<void> deleteAppointment(String appointmentId) async {
    await _col.doc(appointmentId).delete();
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSlotOccupied(AppointmentStatus status) =>
      status == AppointmentStatus.approved;

  Future<List<AppointmentModel>> _getAppointmentsForCounsellorOnDate({
    required String counsellorId,
    required DateTime appointmentDate,
  }) async {
    final start = _normalizeDate(appointmentDate);
    final end = start.add(const Duration(days: 1));

    final snapshot = await _col
        .where('counsellorId', isEqualTo: counsellorId)
        .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('appointmentDate', isLessThan: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.map(AppointmentModel.fromFirestore).toList();
  }

  /// Returns `true` when an approved appointment already occupies the slot.
  Future<bool> hasSlotConflict({
    required String counsellorId,
    required DateTime appointmentDate,
    required String appointmentTime,
  }) async {
    final appointments = await _getAppointmentsForCounsellorOnDate(
      counsellorId: counsellorId,
      appointmentDate: appointmentDate,
    );

    return appointments.any(
      (appointment) =>
          appointment.appointmentTime == appointmentTime &&
          _isSlotOccupied(appointment.status),
    );
  }

  /// Returns [appointmentTime] values occupied by approved appointments.
  Future<Set<String>> getOccupiedTimeSlots({
    required String counsellorId,
    required DateTime appointmentDate,
  }) async {
    final appointments = await _getAppointmentsForCounsellorOnDate(
      counsellorId: counsellorId,
      appointmentDate: appointmentDate,
    );

    return appointments
        .where((appointment) => _isSlotOccupied(appointment.status))
        .map((appointment) => appointment.appointmentTime)
        .toSet();
  }

  /// Returns `true` when another appointment is already approved for the slot.
  Future<bool> hasApprovedSlotConflict({
    required String counsellorId,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String excludeAppointmentId,
  }) async {
    final appointments = await _getAppointmentsForCounsellorOnDate(
      counsellorId: counsellorId,
      appointmentDate: appointmentDate,
    );

    return appointments.any(
      (appointment) =>
          appointment.id != excludeAppointmentId &&
          appointment.appointmentTime == appointmentTime &&
          appointment.status == AppointmentStatus.approved,
    );
  }

  static const autoRejectConflictingPendingRemark =
      'This appointment was automatically rejected because the selected time slot has been assigned to another student.';

  /// Rejects other pending appointments for the same counsellor slot after
  /// [approvedAppointmentId] has been approved.
  ///
  /// Returns the number of appointments rejected.
  Future<int> rejectConflictingPendingAppointments({
    required String approvedAppointmentId,
    required String counsellorId,
    required DateTime appointmentDate,
    required String appointmentTime,
  }) async {
    final appointments = await _getAppointmentsForCounsellorOnDate(
      counsellorId: counsellorId,
      appointmentDate: appointmentDate,
    );

    final conflicts = appointments.where(
      (appointment) =>
          appointment.id != approvedAppointmentId &&
          appointment.appointmentTime == appointmentTime &&
          appointment.status == AppointmentStatus.pending,
    );

    final batch = FirebaseFirestore.instance.batch();
    var rejectedCount = 0;

    for (final appointment in conflicts) {
      batch.update(_col.doc(appointment.id), {
        'status': AppointmentStatus.rejected.firestoreValue,
        'remarks': autoRejectConflictingPendingRemark,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rejectedCount++;
    }

    if (rejectedCount > 0) {
      await batch.commit();
    }

    return rejectedCount;
  }

  /// Returns a live stream of all appointments for [studentId], ordered by
  /// `appointmentDate` descending (most recent first).
  ///
  /// Requires a composite Firestore index on `studentId` + `appointmentDate`.
  Stream<List<AppointmentModel>> watchAppointmentsByStudent(String studentId) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of all appointments for [counsellorId], ordered by
  /// `appointmentDate` descending (most recent first).
  ///
  /// Requires a composite Firestore index on `counsellorId` + `appointmentDate`.
  Stream<List<AppointmentModel>> watchAppointmentsByCounsellor(
    String counsellorId,
  ) {
    return _col
        .where('counsellorId', isEqualTo: counsellorId)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of all appointments for admin reporting, ordered by
  /// `appointmentDate` descending (most recent first).
  Stream<List<AppointmentModel>> getAllAppointments() {
    return _col
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns appointments whose `appointmentDate` falls within [from]–[to]
  /// (inclusive calendar days in local time), ordered by `appointmentDate`
  /// descending.
  Stream<List<AppointmentModel>> getAppointmentsByDateRange({
    required DateTime from,
    required DateTime to,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive =
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    return _col
        .where(
          'appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'appointmentDate',
          isLessThan: Timestamp.fromDate(endExclusive),
        )
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentModel.fromFirestore(doc))
              .toList(),
        );
  }
}
