import 'package:flutter/material.dart';

class ScholarshipDetailScreen extends StatelessWidget {
  final String title;
  final String details;

  const ScholarshipDetailScreen({
    super.key,
    required this.title,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).cardColor,
              ),
              child: Text(
                details,
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Apply feature coming soon")),
                );
              },
              child: const Text("Apply Scholarship"),
            )
          ],
        ),
      ),
    );
  }
}