import 'package:flutter/material.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 mock data（先不要接 backend）
    final appointment = {
      "student": "Ali",
      "reason": "Anxiety",
      "mode": "Online",
      "date": "12 March 2026",
      "time": "10:00 AM",
      "status": "Pending",
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 SECTION 1: Student Info
            const Text(
              "Student Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            _infoRow("Student", appointment["student"]!),
            _infoRow("Reason", appointment["reason"]!),
            _infoRow("Mode", appointment["mode"]!),

            const SizedBox(height: 20),

            // 🔥 SECTION 2: Appointment Info
            const Text(
              "Appointment Details",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            _infoRow("Date", appointment["date"]!),
            _infoRow("Time", appointment["time"]!),
            _infoRow("Status", appointment["status"]!),

            const SizedBox(height: 20),

            // 🔥 SECTION 3: Remarks
            const Text(
              "Remarks",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Add notes about this session...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const Spacer(),

            // 🔥 ACTIONS（Approve / Reject / Reschedule）
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: approve logic
                        },
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
                        onPressed: () {
                          // TODO: reject logic
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Reject"),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                          context, '/rescheduleAppointment');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Reschedule Appointment"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Info Row（對齊）
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}