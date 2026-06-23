import 'package:cloud_firestore/cloud_firestore.dart';

/// A scholarship record stored in the `scholarships` Firestore collection.
///
/// Firestore document shape:
/// ```json
/// {
///   "title": "Pre-University Merit Scholarship (100%)",
///   "category": "Pre-University",
///   "description": "...",
///   "eligibilityCriteria": "...",
///   "waiverPercentage": 100,
///   "retentionCriteria": "...",
///   "isActive": true,
///   "createdAt": Timestamp,
///   "updatedAt": Timestamp
/// }
/// ```
class ScholarshipModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final String eligibilityCriteria;
  final int waiverPercentage;
  final String retentionCriteria;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScholarshipModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.eligibilityCriteria,
    required this.waiverPercentage,
    required this.retentionCriteria,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  String get waiverLabel => '$waiverPercentage% Tuition Fee Waiver';

  Map<String, dynamic> toFirestore({bool includeTimestamps = true}) {
    return {
      'title': title,
      'category': category,
      'description': description,
      'eligibilityCriteria': eligibilityCriteria,
      'waiverPercentage': waiverPercentage,
      'retentionCriteria': retentionCriteria,
      'isActive': isActive,
      if (includeTimestamps) ...{
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
    };
  }

  factory ScholarshipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return ScholarshipModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      eligibilityCriteria: data['eligibilityCriteria'] as String? ?? '',
      waiverPercentage: (data['waiverPercentage'] as num?)?.toInt() ?? 0,
      retentionCriteria: data['retentionCriteria'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
    );
  }

  ScholarshipModel copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? eligibilityCriteria,
    int? waiverPercentage,
    String? retentionCriteria,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScholarshipModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      eligibilityCriteria: eligibilityCriteria ?? this.eligibilityCriteria,
      waiverPercentage: waiverPercentage ?? this.waiverPercentage,
      retentionCriteria: retentionCriteria ?? this.retentionCriteria,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
