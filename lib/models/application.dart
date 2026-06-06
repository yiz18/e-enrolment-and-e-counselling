import 'package:cloud_firestore/cloud_firestore.dart';

/// Application review status stored in Firestore as a string.
enum ApplicationStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ApplicationStatus(this.firestoreValue);

  final String firestoreValue;

  static ApplicationStatus fromFirestore(String? value) {
    return ApplicationStatus.values.firstWhere(
      (s) => s.firestoreValue == value,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

/// A student's course application stored in the `applications` collection.
///
/// ### Firestore document shape
/// ```json
/// {
///   "userId":       "abc123",
///   "studentName":  "Jane Doe",
///   "studentEmail": "jane@example.com",
///   "courseId":     "BCS",
///   "courseCode":   "BCS",
///   "courseName":   "Bachelor of Computer Science",
///   "status":       "Pending",
///   "appliedAt":    Timestamp(...),
///   "updatedAt":    Timestamp(...)
/// }
/// ```
class ApplicationModel {
  final String id;
  final String userId;
  final String studentName;
  final String studentEmail;
  final String courseId;
  final String courseCode;
  final String courseName;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime updatedAt;

  const ApplicationModel({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.studentEmail,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.status,
    required this.appliedAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'courseId': courseId,
        'courseCode': courseCode,
        'courseName': courseName,
        'status': status.firestoreValue,
        'appliedAt': Timestamp.fromDate(appliedAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory ApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return ApplicationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseCode: data['courseCode'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      status: ApplicationStatus.fromFirestore(data['status'] as String?),
      appliedAt:
          (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
    );
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  ApplicationModel copyWith({
    String? id,
    String? userId,
    String? studentName,
    String? studentEmail,
    String? courseId,
    String? courseCode,
    String? courseName,
    ApplicationStatus? status,
    DateTime? appliedAt,
    DateTime? updatedAt,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
