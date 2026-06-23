import 'package:flutter/material.dart';

import '../models/scholarship.dart';
import '../navigation/logout_navigation.dart';
import '../services/scholarship_service.dart';

/// Admin screen for managing scholarship records in Firestore.
class ManageScholarshipsScreen extends StatefulWidget {
  const ManageScholarshipsScreen({super.key});

  @override
  State<ManageScholarshipsScreen> createState() =>
      _ManageScholarshipsScreenState();
}

class _ManageScholarshipsScreenState extends State<ManageScholarshipsScreen> {
  final _service = ScholarshipService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Scholarships'),
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
      body: StreamBuilder<List<ScholarshipModel>>(
        stream: _service.getScholarships(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load scholarships.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final scholarships = snapshot.data ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${scholarships.length} scholarship(s)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showScholarshipForm(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Scholarship'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: scholarships.isEmpty
                    ? const Center(
                        child: Text(
                          'No scholarships yet. Add one to get started.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: scholarships.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final scholarship = scholarships[index];
                          return _ScholarshipAdminCard(
                            scholarship: scholarship,
                            onEdit: () =>
                                _showScholarshipForm(scholarship: scholarship),
                            onToggleActive: () =>
                                _toggleActive(scholarship),
                            onDelete: () => _confirmDelete(scholarship),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(ScholarshipModel scholarship) async {
    try {
      await _service.updateScholarship(
        scholarship.copyWith(isActive: !scholarship.isActive),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scholarship.isActive
                ? 'Scholarship deactivated.'
                : 'Scholarship activated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _confirmDelete(ScholarshipModel scholarship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scholarship'),
        content: Text(
          'Delete "${scholarship.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteScholarship(scholarship.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scholarship deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _showScholarshipForm({ScholarshipModel? scholarship}) async {
    final isEditing = scholarship != null;
    final titleController =
        TextEditingController(text: scholarship?.title ?? '');
    final categoryController =
        TextEditingController(text: scholarship?.category ?? '');
    final descriptionController =
        TextEditingController(text: scholarship?.description ?? '');
    final eligibilityController =
        TextEditingController(text: scholarship?.eligibilityCriteria ?? '');
    final retentionController =
        TextEditingController(text: scholarship?.retentionCriteria ?? '');
    final waiverController = TextEditingController(
      text: scholarship?.waiverPercentage.toString() ?? '',
    );
    var isActive = scholarship?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Scholarship' : 'Add Scholarship'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: waiverController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Waiver Percentage',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: eligibilityController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Eligibility Criteria',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: retentionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Retention Criteria',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      titleController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
      eligibilityController.dispose();
      retentionController.dispose();
      waiverController.dispose();
      return;
    }

    final waiver = int.tryParse(waiverController.text.trim());
    if (titleController.text.trim().isEmpty ||
        categoryController.text.trim().isEmpty ||
        waiver == null ||
        waiver < 0 ||
        waiver > 100) {
      titleController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
      eligibilityController.dispose();
      retentionController.dispose();
      waiverController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in title, category, and a valid waiver percentage (0–100).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now().toUtc();
    final model = ScholarshipModel(
      id: scholarship?.id ?? '',
      title: titleController.text.trim(),
      category: categoryController.text.trim(),
      description: descriptionController.text.trim(),
      eligibilityCriteria: eligibilityController.text.trim(),
      waiverPercentage: waiver,
      retentionCriteria: retentionController.text.trim(),
      isActive: isActive,
      createdAt: scholarship?.createdAt ?? now,
      updatedAt: now,
    );

    titleController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    eligibilityController.dispose();
    retentionController.dispose();
    waiverController.dispose();

    try {
      if (isEditing) {
        await _service.updateScholarship(model);
      } else {
        await _service.addScholarship(model);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Scholarship updated.' : 'Scholarship added.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

class _ScholarshipAdminCard extends StatelessWidget {
  const _ScholarshipAdminCard({
    required this.scholarship,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final ScholarshipModel scholarship;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scholarship.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scholarship.category,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(isActive: scholarship.isActive),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              scholarship.waiverLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scholarship.eligibilityCriteria,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(
                    scholarship.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(scholarship.isActive ? 'Deactivate' : 'Activate'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }
}
