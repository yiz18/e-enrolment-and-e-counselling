import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "Select Your Role",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            _roleCard(
              context,
              icon: Icons.school,
              label: "Student",
              role: 'student',
            ),

            const SizedBox(height: 20),

            _roleCard(
              context,
              icon: Icons.admin_panel_settings,
              label: "Admin",
              role: 'admin',
            ),

            const SizedBox(height: 20),

            _roleCard(
              context,
              icon: Icons.psychology,
              label: "Counsellor",
              role: 'counsellor',
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String role,
      }) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/login',
          arguments: role, // set role
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.blueAccent),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 18),
            )
          ],
        ),
      ),
    );
  }
}