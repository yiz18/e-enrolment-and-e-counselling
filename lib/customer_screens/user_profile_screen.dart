import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/student_profile.dart';
import '../navigation/logout_navigation.dart';
import '../services/user_profile_service.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _profileService = UserProfileService();

  bool _loading = true;
  bool _uploadingPhoto = false;
  String? _error;
  StudentProfile? _profile;

  static const _notProvided = 'Not Provided';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Please sign in to view your profile.';
        _loading = false;
      });
      return;
    }

    try {
      final profile = await _profileService.getCurrentProfile();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        if (showLoading) _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile.\n$e';
        if (showLoading) _loading = false;
      });
    }
  }

  String _displayValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return _notProvided;
    return trimmed;
  }

  Future<void> _openEditProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );

    if (saved == true && mounted) {
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_uploadingPhoto) return;

    final source = await _showImageSourceSheet();
    if (source == null || !mounted) return;

    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingPhoto = true);

      await _profileService.uploadProfilePhoto(picked);

      if (!mounted) return;
      await _loadProfile(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    if (kIsWeb) {
      return ImageSource.gallery;
    }

    final source = await showModalBottomSheet<ImageSource>(
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

    if (source == ImageSource.camera && !await _isCameraSupported()) {
      if (!mounted) return ImageSource.gallery;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is not available. Opening gallery instead.'),
        ),
      );
      return ImageSource.gallery;
    }

    return source;
  }

  Future<bool> _isCameraSupported() async {
    if (kIsWeb) return false;

    final picker = ImagePicker();
    try {
      return await picker.supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickProfilePhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ProfileAvatar(imageUrl: profile.profileImageUrl),
                if (_uploadingPhoto)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _displayValue(profile.fullName),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _displayValue(profile.email),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _ProfileListTile(
            icon: Icons.phone,
            title: 'Phone Number',
            value: _displayValue(profile.phoneNumber),
          ),
          _ProfileListTile(
            icon: Icons.badge_outlined,
            title: 'IC / Passport Number',
            value: _displayValue(profile.icPassportNumber),
          ),
          _ProfileListTile(
            icon: Icons.wc_outlined,
            title: 'Gender',
            value: _displayValue(profile.gender),
          ),
          _ProfileListTile(
            icon: Icons.home_outlined,
            title: 'Address',
            value: _displayValue(profile.address),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: _openEditProfile,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => logoutToRoleSelection(context),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.blueAccent,
        child: ClipOval(
          child: Image.network(
            url,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.person,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 50,
      backgroundColor: Colors.blueAccent,
      child: Icon(Icons.person, size: 50, color: Colors.white),
    );
  }
}

class _ProfileListTile extends StatelessWidget {
  const _ProfileListTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
