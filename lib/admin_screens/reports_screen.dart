import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      {
        "title": "2026 Enrolment Report",
        "type": "enrolment",
        "date": "12 March 2026"
      },
      {
        "title": "March Counselling Report",
        "type": "counselling",
        "date": "12 March 2026"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔥 Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text("Generate New Report"),
              ),
            ),

            const SizedBox(height: 16),

            // 🔍 Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search reports...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 📄 Report List
            Expanded(
              child: ListView.separated(
                itemCount: reports.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final report = reports[index];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),

                    leading: _buildReportIcon(report["type"]!),

                    title: Text(
                      report["title"]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    subtitle: Text(
                      report["date"]!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),

                    trailing: const Icon(Icons.chevron_right),

                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/reportView',
                        arguments: report["type"],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportIcon(String type) {
    switch (type) {
      case "enrolment":
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Colors.red),
        );

      case "counselling":
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description, color: Colors.blue),
        );

      default:
        return const Icon(Icons.insert_drive_file);
    }
  }
}