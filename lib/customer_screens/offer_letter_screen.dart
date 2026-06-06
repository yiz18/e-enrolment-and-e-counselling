import 'package:flutter/material.dart';

class OfferLetterScreen extends StatelessWidget {
  const OfferLetterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Offer Letter"),
        backgroundColor: Colors.blueAccent,
      ),

      // 🔥 按钮移到外面
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("Accept Offer"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text("Reject"),
              ),
            ),
          ],
        ),
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600), // 📄 A4感
            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: Colors.white, // 🔥 纸张
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🏫 Header
                const Text(
                  "Tunku Abdul Rahman University of Management and Technology",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 8),

                const Text("Penang Branch"),

                const SizedBox(height: 16),
                const Divider(),

                // 📄 Ref Info
                const Text("Ref No: 02404096/SP/A016/ORTN"),
                const Text("Date: 02 July 2024"),

                const SizedBox(height: 20),

                // 👤 Student Info
                const Text(
                  "Student Name",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text("XXXXXX-XX-XXXX"),

                const SizedBox(height: 20),

                const Text(
                  "OFFER OF ADMISSION - MAY 2026 INTAKE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  "Congratulations! We are pleased to inform that you have been offered admission to the programme as follows:",
                ),

                const SizedBox(height: 20),

                // 🎓 Programme Box（改成像文件框）
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400,width: 1.5,),

                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bachelor of Software Engineering (Honours)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text("Year 1 Semester 1, Penang Branch"),
                      SizedBox(height: 6),
                      Text("Commencement Date: 24 May 2026"),
                      Text("Duration: 3 Years"),
                      Text("Mode: Full Time"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 📚 Credit Transfer
                const Text(
                  "Credit Transfer:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text("BACS1013 - Problem Solving and Programming (3)"),
                const Text("BACS2023 - Object-Oriented Programming (3)"),
                const Text("BACS2093 - Operating Systems (3)"),
                const Text("BAIT2004 - Computer Networks (4)"),

                const SizedBox(height: 20),

                // ⚠️ Notice
                const Text(
                  "Please complete your payment before 05 June 2026 to confirm your admission.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}