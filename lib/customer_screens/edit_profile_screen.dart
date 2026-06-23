import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/user_profile_service.dart';

/// Form for editing the signed-in student's profile fields.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = UserProfileService();

  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _icPassportController;
  late final TextEditingController _genderController;
  late final TextEditingController _addressController;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  StudentProfile? _profile;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _icPassportController = TextEditingController();
    _genderController = TextEditingController();
    _addressController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.getCurrentProfile();
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _error = 'Please sign in to edit your profile.';
          _loading = false;
        });
        return;
      }

      _fullNameController.text = profile.fullName ?? '';
      _phoneController.text = profile.phoneNumber ?? '';
      _icPassportController.text = profile.icPassportNumber ?? '';
      _genderController.text = profile.gender ?? '';
      _addressController.text = profile.address ?? '';

      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile.\n$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _icPassportController.dispose();
    _genderController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _saving = true);

    try {
      await _service.updateProfile(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        icPassportNumber: _icPassportController.text,
        gender: _genderController.text,
        address: _addressController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _fullNameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full Name cannot be empty.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: profile.email ?? '',
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _icPassportController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'IC / Passport Number',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _genderController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              enabled: !_saving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
