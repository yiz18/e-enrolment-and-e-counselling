import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../models/user_role.dart';
import '../navigation/logout_navigation.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';

class CounsellorProfileScreen extends StatefulWidget {
  const CounsellorProfileScreen({super.key});

  @override
  State<CounsellorProfileScreen> createState() =>
      _CounsellorProfileScreenState();
}

class _CounsellorProfileScreenState extends State<CounsellorProfileScreen> {
  final _profileService = UserProfileService();
  final _authService = AuthService();

  static const _notProvided = 'Not Provided';

  String _roleLabel = 'Counsellor';

  @override
  void initState() {
    super.initState();
    _loadRoleLabel();
  }

  Future<void> _loadRoleLabel() async {
    final appUser = await _authService.getCurrentAppUser();
    if (!mounted) return;
    setState(() => _roleLabel = _roleLabelFor(appUser?.role));
  }

  String _roleLabelFor(String? role) {
    switch (role) {
      case UserRole.counsellor:
        return 'Student Counsellor';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.student:
        return 'Student';
      default:
        return 'Counsellor';
    }
  }

  String _displayValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return _notProvided;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<StudentProfile?>(
        stream: _profileService.watchCurrentProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load profile.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(
              child: Text('Please sign in to view your profile.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      _CounsellorProfileAvatar(
                        imageUrl: profile.profileImageUrl,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayValue(profile.fullName),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleLabel,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Contact Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _infoRow(Icons.phone, _displayValue(profile.phoneNumber)),
                _infoRow(Icons.email, _displayValue(profile.email)),
                const SizedBox(height: 20),
                const Text(
                  'Personal Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _infoRow(Icons.wc_outlined, _displayValue(profile.gender)),
                _infoRow(Icons.location_on, _displayValue(profile.address)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => logoutToRoleSelection(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CounsellorProfileAvatar extends StatelessWidget {
  const _CounsellorProfileAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: const Color(0xFFE6DDFF),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return const CircleAvatar(
      radius: 40,
      backgroundColor: Color(0xFFE6DDFF),
      child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
    );
  }
}
