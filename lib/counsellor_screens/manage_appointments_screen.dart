import 'package:flutter/material.dart';

class ManageAppointmentsScreen extends StatelessWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointments = [
      {"name": "Ali", "time": "10:00 AM", "status": "Pending"},
      {"name": "Tan", "time": "2:00 PM", "status": "Completed"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Appointments"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final a = appointments[index];

          return Card(
            child: ListTile(
              title: Text(a["name"]!),
              subtitle: Text("${a["time"]} • ${a["status"]}"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(context, '/appointmentDetail');
              },
            ),
          );
        },
      ),
    );
  }
}