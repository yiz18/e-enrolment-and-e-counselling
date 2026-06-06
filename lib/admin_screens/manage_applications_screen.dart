import 'package:flutter/material.dart';

class ManageApplicationsScreen extends StatelessWidget {
  const ManageApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupedData = {
      "Faculty of Computing and Information Technology": [
        {
          "name": "Ali",
          "programme": "Software Engineering",
          "status": "Pending"
        },
        {
          "name": "Tan",
          "programme": "Data Science",
          "status": "Approved"
        },
      ],
      "Faculty of Engineering and Technology": [
        {
          "name": "Kumar",
          "programme": "Mechanical Engineering",
          "status": "Pending"
        },
      ],
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Applications"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: groupedData.entries.map((entry) {
          final faculty = entry.key;
          final apps = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 Faculty Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  faculty,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 🔥 Divider
              const Divider(),

              // 🔥 List
              ...apps.map((app) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),

                  title: Text(
                    app["name"]!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  subtitle: Text(app["programme"]!),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statusBadge(app["status"]!),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),

                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/adminApplicationDetail',
                      arguments: app,
                    );
                  },
                );
              }).toList(),

              const SizedBox(height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 🔥 Status Badge
  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case "Pending":
        color = Colors.orange;
        break;
      case "Approved":
        color = Colors.green;
        break;
      case "Rejected":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}