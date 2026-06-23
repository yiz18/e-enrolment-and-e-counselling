import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/student_document.dart';
import '../services/student_document_service.dart';
import '../widgets/document_image_preview.dart';

/// Screen for uploading supporting academic documents via Cloudinary.
class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _service = StudentDocumentService();
  final _picker = ImagePicker();
  StudentDocumentType? _uploadingType;

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: user == null
          ? const Center(
              child: Text('Please sign in to upload documents.'),
            )
          : StreamBuilder<StudentDocumentModel?>(
              stream: _service.watchStudentDocuments(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load documents.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: StudentDocumentType.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final type = StudentDocumentType.values[index];
                    final fileCount = documents?.uploadedCount(type) ?? 0;
                    final isUploading = _uploadingType == type;
                    final urls = documents?.urlsForType(type) ?? [];

                    return _DocumentCard(
                      type: type,
                      fileCount: fileCount,
                      isUploading: isUploading,
                      uploadedAt:
                          fileCount > 0 ? documents?.updatedAt : null,
                      formatDate: _formatDate,
                      onUpload: () => _pickAndUpload(user.uid, type),
                      onAddMore: () => _pickAndUpload(user.uid, type),
                      onViewFiles: () => DocumentImagePreview.showFilesSheet(
                        context,
                        title: type.label,
                        urls: urls,
                        onDelete: (url) => _service.deleteDocumentUrl(
                          userId: user.uid,
                          type: type,
                          url: url,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _pickAndUpload(String userId, StudentDocumentType type) async {
    final source = await _showImageSourceSheet();
    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingType = type);

      await _service.uploadDocument(
        userId: userId,
        type: type,
        file: File(picked.path),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${type.label} uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Document upload error: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      final message = e is Exception ? e.toString() : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.type,
    required this.fileCount,
    required this.isUploading,
    required this.uploadedAt,
    required this.formatDate,
    required this.onUpload,
    required this.onAddMore,
    required this.onViewFiles,
  });

  final StudentDocumentType type;
  final int fileCount;
  final bool isUploading;
  final DateTime? uploadedAt;
  final String Function(DateTime date) formatDate;
  final VoidCallback onUpload;
  final VoidCallback onAddMore;
  final VoidCallback onViewFiles;

  @override
  Widget build(BuildContext context) {
    final hasFiles = fileCount > 0;
    final statusColor = hasFiles ? Colors.green : Colors.orange;
    final statusLabel = hasFiles ? 'Uploaded' : 'Not Uploaded';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasFiles) ...[
              const SizedBox(height: 10),
              Text(
                'Uploaded: $fileCount file${fileCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (uploadedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Last updated: ${formatDate(uploadedAt!.toLocal())}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!hasFiles)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewFiles,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('View Files'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAddMore,
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          size: 18),
                      label: const Text('Add More'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
