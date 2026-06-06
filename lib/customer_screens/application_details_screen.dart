import 'package:flutter/material.dart';

class ApplicationDetailsScreen extends StatelessWidget {
  const ApplicationDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Application Details"),
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  "Application Details",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 Programme
                const Text(
                  "Programme",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("Bachelor of Software Engineering"),

                const SizedBox(height: 20),

                // 🔹 Intake
                const Text(
                  "Intake",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("May 2026"),

                const SizedBox(height: 20),

                // 🔹 Submission Date
                const Text(
                  "Submission Date",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("02 April 2026"),

                const SizedBox(height: 20),

                // 🔹 Documents
                const Text(
                  "Documents Submitted",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text("IC Copy"),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text("Transcript"),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text("Certificate"),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 🔹 Remarks
                const Text(
                  "Remarks",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("Application is under review."),
              ],
            ),
          ),
        ),
      ),
    );
  }
}