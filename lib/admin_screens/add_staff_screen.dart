import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/staff_service.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key, required this.role});

  final String role;

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _staffService = StaffService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;

  String get _title =>
      widget.role == UserRole.admin ? 'Add New Admin' : 'Add New Counsellor';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateForm() {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty) return 'Please enter the full name.';
    if (email.isEmpty) return 'Please enter the email.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (password != confirmPassword) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _staffService.createStaffAccount(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: widget.role,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_title account created successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new ${widget.role} account. Your admin session will remain active.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),
            _buildField(
              label: 'Full Name',
              controller: _nameController,
              hint: 'Enter full name',
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'Email',
              controller: _emailController,
              hint: 'Enter email address',
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'Password',
              controller: _passwordController,
              hint: 'Create a password',
              isDark: isDark,
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              hint: 'Re-enter password',
              isDark: isDark,
              obscureText: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Create ${widget.role[0].toUpperCase()}${widget.role.substring(1)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
