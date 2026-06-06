import 'package:flutter/material.dart';

class StudentRecordsScreen extends StatelessWidget {
  const StudentRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final students = [
      {
        "name": "Ali",
        "programme": "Software Engineering",
        "lastSession": "10 March 2026"
      },
      {
        "name": "Tan",
        "programme": "IT",
        "lastSession": "8 March 2026"
      },
      {
        "name": "Kumar",
        "programme": "Mechanical Engineering",
        "lastSession": "5 March 2026"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Records"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final student = students[index];

          return ListTile(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 8),

            title: Text(
              student["name"]!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            subtitle: Text(
              "${student["programme"]}\nLast session: ${student["lastSession"]}",
            ),

            isThreeLine: true,

            trailing: const Icon(Icons.chevron_right),

            onTap: () {
              Navigator.pushNamed(
                context,
                '/historyDetailPage',
                arguments: student,
              );
            },
          );
        },
      ),
    );
  }
}