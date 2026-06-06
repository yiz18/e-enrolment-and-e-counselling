import 'package:flutter/material.dart';

class AppointmentHistoryDetailScreen extends StatelessWidget {
  const AppointmentHistoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 mock student + history data
    final student =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {
              "name": "Ali",
              "programme": "Software Engineering",
            };

    final history = [
      {
        "date": "10 March 2026",
        "reason": "Anxiety",
        "time": "10:00 AM",
        "mode": "Online",
        "status": "Completed",
        "remarks": "Student felt better after session"
      },
      {
        "date": "5 March 2026",
        "reason": "Stress",
        "time": "2:00 PM",
        "mode": "Face-to-face",
        "status": "Completed",
        "remarks": "Discussed coping strategies"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment History"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 Student Info
            Text(
              student["name"],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(student["programme"]),

            const SizedBox(height: 20),

            const Text(
              "History",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // 🔥 History List
            Expanded(
              child: ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final h = history[index];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // 🔥 Top Row (Reason + Status)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              h["reason"]!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            _statusBadge(h["status"]!),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // 🔥 Date + Time
                        Text("${h["date"]} • ${h["time"]}"),

                        // 🔥 Mode
                        Text("Mode: ${h["mode"]}"),

                        const SizedBox(height: 6),

                        // 🔥 Remarks
                        Text(
                          "Remarks: ${h["remarks"]}",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Status Badge
  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case "Completed":
        color = Colors.green;
        break;
      case "Pending":
        color = Colors.orange;
        break;
      case "Cancelled":
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