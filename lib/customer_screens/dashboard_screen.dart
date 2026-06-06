import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),

      /// 🔥 💬 FLOATING CHAT BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/chatbot');
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.chat),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔥 Welcome
            const Text(
              "Welcome 👋",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            /// 🔥 Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Application Status",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text("Status: Pending"),
                  SizedBox(height: 6),
                  Text(
                    "Next Step: Upload your academic documents",
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// 🔥 Quick Actions
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _quickButton(
                    icon: Icons.description,
                    label: "Continue",
                    onTap: () => Navigator.pushNamed(context, '/enrolment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickButton(
                    icon: Icons.upload_file,
                    label: "Upload",
                    onTap: () => Navigator.pushNamed(context, '/upload'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickButton(
                    icon: Icons.calendar_today,
                    label: "Counselling",
                    onTap: () => Navigator.pushNamed(context, '/appointment'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// 🔥 Features
            const Text(
              "All Features",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [

                _featureCard(Icons.upload_file, "Upload", '/upload', context),
                _featureCard(Icons.school, "Recommendation", '/recommendation', context),
                _featureCard(Icons.assignment, "My Applications", '/myApplications', context),
                _featureCard(Icons.psychology_outlined, "Interests", '/interest-profile', context),
                _featureCard(Icons.assignment, "Enrolment", '/enrolment', context),
                _featureCard(Icons.track_changes, "Status", '/applicationStatus', context),
                _featureCard(Icons.description, "Offer", '/offerLetter', context),
                _featureCard(Icons.payment, "Payment", '/payment', context),
                _featureCard(Icons.card_giftcard, "Scholarship", '/scholarship', context),
                _featureCard(Icons.event, "Appointment", '/appointment', context),

                /// ❌ REMOVE chatbot card（已用floating button）
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
      IconData icon,
      String label,
      String route,
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}