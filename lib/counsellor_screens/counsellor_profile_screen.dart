import 'package:flutter/material.dart';

import '../navigation/logout_navigation.dart';

class CounsellorProfileScreen extends StatelessWidget {
  const CounsellorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final counsellor = {
      "name": "Ms Perng Soo Chen",
      "role": "Student Counsellor",
      "phone": "04-8995230 ext. 172",
      "email": "perngsc@tarc.edu.my",
      "division": "Division of Students Affairs",
      "location": "Ground Floor, Block B",
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 Profile Header
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFE6DDFF),
                    child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    counsellor["name"]!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    counsellor["role"]!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 Contact Info
            const Text(
              "Contact Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _infoRow(Icons.phone, counsellor["phone"]!),
            _infoRow(Icons.email, counsellor["email"]!),

            const SizedBox(height: 20),

            // 🔥 Workplace Info
            const Text(
              "Workplace",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _infoRow(Icons.business, counsellor["division"]!),
            _infoRow(Icons.location_on, counsellor["location"]!),

            const Spacer(),

            // 🔥 Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => logoutToRoleSelection(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Row with Icon
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