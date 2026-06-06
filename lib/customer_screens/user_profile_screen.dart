import 'package:flutter/material.dart';

import '../navigation/logout_navigation.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Profile"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // 🔥 Avatar
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),

            const SizedBox(height: 16),

            const Text(
              "User Name",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text("User@email.com"),

            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Profile"),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () => logoutToRoleSelection(context),
            ),
          ],
        ),
      ),
    );
  }
}