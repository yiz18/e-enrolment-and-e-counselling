import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/application.dart';
import '../models/credit_transfer_subject.dart';
import '../models/student_document.dart';
import '../navigation/logout_navigation.dart';
import '../services/application_service.dart';
import '../services/student_document_query_service.dart';
import '../widgets/application_status_chip.dart';
import '../widgets/document_image_preview.dart';

/// Admin screen for reviewing all submitted course applications.
class ApplicationManagementScreen extends StatefulWidget {
  const ApplicationManagementScreen({super.key});

  @override
  State<ApplicationManagementScreen> createState() =>
      _ApplicationManagementScreenState();
}

class _ApplicationManagementScreenState
    extends State<ApplicationManagementScreen> {
  final _service = ApplicationService();

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Application Management'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 768)
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'logout') {
                  logoutToRoleSelection(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.pushNamed(context, '/adminProfile'),
            ),
        ],
      ),
      body: StreamBuilder<List<ApplicationModel>>(
        stream: _service.getAllApplications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load applications.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final applications = snapshot.data ?? [];

          if (applications.isEmpty) {
            return const Center(
              child: Text(
                'No applications found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final application = applications[index];
              return _ApplicationCard(
                application: application,
                formattedDate:
                    _formatDate(application.appliedAt.toLocal()),
                onTap: () => _showReviewDialog(context, application),
              );
            },
          );
        },
      ),
    );
  }

  void _showReviewDialog(BuildContext context, ApplicationModel application) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ApplicationReviewDialog(
        application: application,
        formattedAppliedDate: _formatDate(application.appliedAt.toLocal()),
        onSave: (status, remark, creditTransfers) async {
          final adminUid = FirebaseAuth.instance.currentUser?.uid;
          if (adminUid == null) {
            throw StateError('Admin is not signed in.');
          }

          await _service.updateApplicationReview(
            applicationId: application.id,
            status: status,
            remark: remark,
            reviewedBy: adminUid,
            creditTransfers: creditTransfers,
          );
        },
        onSuccess: () {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update application: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.formattedDate,
    required this.onTap,
  });

  final ApplicationModel application;
  final String formattedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      application.courseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ApplicationStatusChip(status: application.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Code: ${application.courseCode}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                'Student ID: ${application.userId}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Applied: $formattedDate',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationReviewDialog extends StatefulWidget {
  const _ApplicationReviewDialog({
    required this.application,
    required this.formattedAppliedDate,
    required this.onSave,
    required this.onSuccess,
    required this.onError,
  });

  final ApplicationModel application;
  final String formattedAppliedDate;
  final Future<void> Function(
    String status,
    String remark,
    List<CreditTransferSubject> creditTransfers,
  ) onSave;
  final VoidCallback onSuccess;
  final void Function(Object error) onError;

  @override
  State<_ApplicationReviewDialog> createState() =>
      _ApplicationReviewDialogState();
}

class _ApplicationReviewDialogState extends State<_ApplicationReviewDialog> {
  final _documentQueryService = StudentDocumentQueryService();

  late ApplicationStatus _selectedStatus;
  late final TextEditingController _remarkController;
  late List<CreditTransferSubject> _creditTransfers;
  bool _saving = false;
  bool _loadingDocuments = true;
  StudentDocumentModel? _studentDocuments;

  static const _statusOptions = ApplicationStatus.values;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.application.status;
    _remarkController = TextEditingController(
      text: widget.application.remark ?? '',
    );
    _creditTransfers = List<CreditTransferSubject>.from(
      widget.application.creditTransfers,
    );
    _loadStudentDocuments();
  }

  Future<void> _loadStudentDocuments() async {
    try {
      final documents = await _documentQueryService.getStudentDocuments(
        widget.application.userId,
      );
      if (!mounted) return;
      setState(() {
        _studentDocuments = documents;
        _loadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDocuments = false);
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);

    try {
      await widget.onSave(
        _selectedStatus.firestoreValue,
        _remarkController.text.trim(),
        _creditTransfers,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.assignment, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              application.courseCode,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Application Information'),
              const SizedBox(height: 10),
              _DetailRow(label: 'Course Name', value: application.courseName),
              _DetailRow(label: 'Course Code', value: application.courseCode),
              _DetailRow(label: 'User ID', value: application.userId),
              _DetailRow(
                label: 'Applied Date',
                value: widget.formattedAppliedDate,
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Review Information'),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Current Status',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  ApplicationStatusChip(status: application.status),
                ],
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: 'Current Remark',
                value: application.displayRemark,
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Uploaded Documents'),
              const SizedBox(height: 10),
              _UploadedDocumentsSection(
                loading: _loadingDocuments,
                documents: _studentDocuments,
                onView: (label, urls) => DocumentImagePreview.showFilesSheet(
                  context,
                  title: label,
                  urls: urls,
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Credit Transfer Subjects'),
              const SizedBox(height: 10),
              _CreditTransferSection(
                subjects: _creditTransfers,
                enabled: !_saving,
                onAdd: _addCreditTransfer,
                onEdit: _editCreditTransfer,
                onDelete: _deleteCreditTransfer,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              DropdownButtonFormField<ApplicationStatus>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: _statusOptions
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.firestoreValue),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedStatus = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarkController,
                maxLines: 3,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Remark',
                  hintText: 'e.g. Eligible for July Intake',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _handleSave,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _addCreditTransfer() async {
    final subject = await _showCreditTransferDialog();
    if (subject == null || !mounted) return;
    setState(() => _creditTransfers.add(subject));
  }

  Future<void> _editCreditTransfer(int index) async {
    final subject = await _showCreditTransferDialog(
      existing: _creditTransfers[index],
    );
    if (subject == null || !mounted) return;
    setState(() => _creditTransfers[index] = subject);
  }

  void _deleteCreditTransfer(int index) {
    setState(() => _creditTransfers.removeAt(index));
  }

  Future<CreditTransferSubject?> _showCreditTransferDialog({
    CreditTransferSubject? existing,
  }) {
    final codeController = TextEditingController(text: existing?.subjectCode);
    final nameController = TextEditingController(text: existing?.subjectName);
    final hoursController = TextEditingController(
      text: existing?.creditHours.toString(),
    );

    return showDialog<CreditTransferSubject>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add Subject' : 'Edit Subject'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Subject Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Credit Hours',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              final name = nameController.text.trim();
              final hours = int.tryParse(hoursController.text.trim());

              if (code.isEmpty || name.isEmpty || hours == null || hours <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid subject details.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(
                dialogContext,
                CreditTransferSubject(
                  subjectCode: code,
                  subjectName: name,
                  creditHours: hours,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _CreditTransferSection extends StatelessWidget {
  const _CreditTransferSection({
    required this.subjects,
    required this.enabled,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CreditTransferSubject> subjects;
  final bool enabled;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subjects.isEmpty)
          Text(
            'No credit transfer subjects added.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          ...List.generate(subjects.length, (index) {
            final subject = subjects[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.displayLine,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: enabled ? () => onEdit(index) : null,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: enabled ? () => onDelete(index) : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
            );
          }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.blueAccent,
      ),
    );
  }
}

class _UploadedDocumentsSection extends StatelessWidget {
  const _UploadedDocumentsSection({
    required this.loading,
    required this.documents,
    required this.onView,
  });

  final bool loading;
  final StudentDocumentModel? documents;
  final void Function(String label, List<String> urls) onView;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (documents == null ||
        !StudentDocumentType.values.any(
          (type) => documents!.urlsForType(type).isNotEmpty,
        )) {
      return Text(
        'No documents uploaded.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      );
    }

    final uploadedTypes = StudentDocumentType.values
        .where((type) => documents!.urlsForType(type).isNotEmpty)
        .toList();

    return Column(
      children: uploadedTypes.map((type) {
        final urls = documents!.urlsForType(type);
        final count = urls.length;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${type.label} ($count file${count == 1 ? '' : 's'})',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => onView(type.label, urls),
                child: const Text('View'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
