import 'package:flutter/material.dart';
import 'scholarship_detail_screen.dart';

class ScholarshipScreen extends StatelessWidget {
  const ScholarshipScreen({super.key});

  final List<Map<String, String>> scholarships = const [
    {
      "title": "Merit Scholarship",
      "details":
      "Eligibility: CGPA > 3.5\nBenefit: 50% Tuition Fee\nRequirement: Academic Excellence"
    },
    {
      "title": "Need-Based Scholarship",
      "details":
      "Eligibility: Low Income\nBenefit: 70% Tuition Fee\nRequirement: Financial Documents"
    },
    {
      "title": "Sports Scholarship",
      "details":
      "Eligibility: Active Athlete\nBenefit: 40% Tuition Fee\nRequirement: Sports Achievement"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scholarship Information"),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: scholarships.length,
        itemBuilder: (context, index) {
          final item = scholarships[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.card_giftcard),
              title: Text(
                item["title"]!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScholarshipDetailScreen(
                      title: item["title"]!,
                      details: item["details"]!,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}