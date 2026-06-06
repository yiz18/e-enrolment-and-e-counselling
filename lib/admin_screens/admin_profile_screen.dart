import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../navigation/logout_navigation.dart';
import '../services/auth_service.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _authService = AuthService();
  AppUser? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getCurrentAppUser();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _logout() => logoutToRoleSelection(context);

  @override
  Widget build(BuildContext context) {
    final name = _profile?.fullName ?? 'Admin';
    final email = _profile?.email ?? _authService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Color(0xFFE6DDFF),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(email),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Admin Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    context,
                    'Staff Management',
                    Icons.groups,
                    '/staffManagement',
                  ),
                  _actionTile(
                    context,
                    'Add New Admin',
                    Icons.admin_panel_settings,
                    '/addAdmin',
                  ),
                  _actionTile(
                    context,
                    'Add New Counsellor',
                    Icons.person_add,
                    '/addCounsellor',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
        child: Icon(icon, color: Colors.blueAccent),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
