import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/staff_service.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final staffService = StaffService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add staff',
            onPressed: () => _showAddStaffMenu(context),
          ),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: staffService.watchStaff(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load staff.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final staff = snapshot.data ?? [];
          if (staff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No staff accounts yet.'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddStaffMenu(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Staff'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _StaffCard(user: staff[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffMenu(context),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }

  void _showAddStaffMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Add New Admin'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/addAdmin');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add New Counsellor'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/addCounsellor');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == UserRole.admin;
    final isActive = user.isStaffActive;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isAdmin ? Colors.deepPurple.shade100 : Colors.teal.shade100,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.support_agent,
                color: isAdmin ? Colors.deepPurple : Colors.teal,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(user.email, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                        label: isAdmin ? 'Admin' : 'Counsellor',
                        color: isAdmin ? Colors.deepPurple : Colors.teal,
                      ),
                      _Badge(
                        label: user.statusLabel,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
