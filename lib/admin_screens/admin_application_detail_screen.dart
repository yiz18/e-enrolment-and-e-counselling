import 'package:flutter/material.dart';

class AdminApplicationDetailScreen extends StatelessWidget {
  const AdminApplicationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {

    // 🔥 先用假資料（避免 null error）
    final app = {
      "name": "Ali",
      "programme": "Software Engineering",
      "status": "Pending",
    };

    final files = [
      {"name": "IC.pdf", "type": "pdf"},
      {"name": "Result.png", "type": "image"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Application Detail"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 Student Info（乾淨版）
            Text("Student: ${app["name"]}"),
            const SizedBox(height: 10),

            Text("Programme: ${app["programme"]}"),
            const SizedBox(height: 10),

            Text("Status: ${app["status"]}"),

            const SizedBox(height: 25),

            // 🔥 FILE SECTION（你要的🔥）
            const Text(
              "Uploaded Documents",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...files.map((file) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _fileIcon(file["type"]!),
                title: Text(file["name"]!),

                // 🔥 Download Button
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    // TODO: download later
                  },
                ),

                onTap: () {
                  // TODO: preview later
                },
              );
            }).toList(),

            const SizedBox(height: 20),

            // 🔥 REMARKS
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Add remarks",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Approve"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Reject"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 File Icon
  Widget _fileIcon(String type) {
    switch (type) {
      case "pdf":
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case "image":
        return const Icon(Icons.image, color: Colors.blue);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }
}