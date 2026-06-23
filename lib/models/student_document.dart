import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported supporting document categories for student upload.
enum StudentDocumentType {
  spmCertificate(
    label: 'SPM Certificate',
    storageFileName: 'spm_certificate.jpg',
    legacyUrlField: 'spmCertificateUrl',
    urlsField: 'spmCertificateUrls',
  ),
  stpmCertificate(
    label: 'STPM Certificate',
    storageFileName: 'stpm_certificate.jpg',
    legacyUrlField: 'stpmCertificateUrl',
    urlsField: 'stpmCertificateUrls',
  ),
  diplomaTranscript(
    label: 'Diploma Transcript',
    storageFileName: 'diploma_transcript.jpg',
    legacyUrlField: 'diplomaTranscriptUrl',
    urlsField: 'diplomaTranscriptUrls',
  ),
  diplomaCertificate(
    label: 'Diploma Certificate',
    storageFileName: 'diploma_certificate.jpg',
    legacyUrlField: 'diplomaCertificateUrl',
    urlsField: 'diplomaCertificateUrls',
  ),
  icPassport(
    label: 'IC / Passport',
    storageFileName: 'ic_passport.jpg',
    legacyUrlField: 'icPassportUrl',
    urlsField: 'icPassportUrls',
  ),
  otherSupportingDocuments(
    label: 'Other Supporting Documents',
    storageFileName: 'other_supporting_document.jpg',
    legacyUrlField: 'otherSupportingDocumentUrl',
    urlsField: 'otherSupportingDocumentUrls',
  );

  const StudentDocumentType({
    required this.label,
    required this.storageFileName,
    required this.legacyUrlField,
    required this.urlsField,
  });

  final String label;
  final String storageFileName;
  final String legacyUrlField;
  final String urlsField;
}

/// Firestore document in `student_documents/{userId}`.
class StudentDocumentModel {
  final String userId;
  final List<String> spmCertificateUrls;
  final List<String> stpmCertificateUrls;
  final List<String> diplomaTranscriptUrls;
  final List<String> diplomaCertificateUrls;
  final List<String> icPassportUrls;
  final List<String> otherSupportingDocumentUrls;
  final DateTime? updatedAt;

  const StudentDocumentModel({
    required this.userId,
    this.spmCertificateUrls = const [],
    this.stpmCertificateUrls = const [],
    this.diplomaTranscriptUrls = const [],
    this.diplomaCertificateUrls = const [],
    this.icPassportUrls = const [],
    this.otherSupportingDocumentUrls = const [],
    this.updatedAt,
  });

  factory StudentDocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return StudentDocumentModel(
      userId: data['userId'] as String? ?? doc.id,
      spmCertificateUrls: _readUrls(
        data,
        StudentDocumentType.spmCertificate.urlsField,
        StudentDocumentType.spmCertificate.legacyUrlField,
      ),
      stpmCertificateUrls: _readUrls(
        data,
        StudentDocumentType.stpmCertificate.urlsField,
        StudentDocumentType.stpmCertificate.legacyUrlField,
      ),
      diplomaTranscriptUrls: _readUrls(
        data,
        StudentDocumentType.diplomaTranscript.urlsField,
        StudentDocumentType.diplomaTranscript.legacyUrlField,
      ),
      diplomaCertificateUrls: _readUrls(
        data,
        StudentDocumentType.diplomaCertificate.urlsField,
        StudentDocumentType.diplomaCertificate.legacyUrlField,
      ),
      icPassportUrls: _readUrls(
        data,
        StudentDocumentType.icPassport.urlsField,
        StudentDocumentType.icPassport.legacyUrlField,
      ),
      otherSupportingDocumentUrls: _readUrls(
        data,
        StudentDocumentType.otherSupportingDocuments.urlsField,
        StudentDocumentType.otherSupportingDocuments.legacyUrlField,
      ),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Merges array URLs with a legacy single-URL field when present.
  static List<String> _readUrls(
    Map<String, dynamic> data,
    String urlsField,
    String legacyUrlField,
  ) {
    final urls = <String>[];

    final rawList = data[urlsField];
    if (rawList is List) {
      for (final item in rawList) {
        final url = item?.toString().trim() ?? '';
        if (url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }

    final legacyUrl = data[legacyUrlField] as String?;
    if (legacyUrl != null) {
      final trimmed = legacyUrl.trim();
      if (trimmed.isNotEmpty && !urls.contains(trimmed)) {
        urls.insert(0, trimmed);
      }
    }

    return urls;
  }

  List<String> urlsForType(StudentDocumentType type) {
    switch (type) {
      case StudentDocumentType.spmCertificate:
        return spmCertificateUrls;
      case StudentDocumentType.stpmCertificate:
        return stpmCertificateUrls;
      case StudentDocumentType.diplomaTranscript:
        return diplomaTranscriptUrls;
      case StudentDocumentType.diplomaCertificate:
        return diplomaCertificateUrls;
      case StudentDocumentType.icPassport:
        return icPassportUrls;
      case StudentDocumentType.otherSupportingDocuments:
        return otherSupportingDocumentUrls;
    }
  }

  int uploadedCount(StudentDocumentType type) => urlsForType(type).length;

  bool isUploaded(StudentDocumentType type) => uploadedCount(type) > 0;

  /// Returns `true` when at least one document URL is stored.
  bool get hasAnyUploaded =>
      StudentDocumentType.values.any(isUploaded);
}
