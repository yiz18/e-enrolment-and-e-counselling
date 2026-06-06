import 'package:flutter/material.dart';

import '../navigation/logout_navigation.dart';

class CounsellorDashboardScreen extends StatelessWidget {
  const CounsellorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Counsellor Dashboard"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 768)
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.pushNamed(context, '/counsellorProfile');
                } else if (value == 'logout') {
                  logoutToRoleSelection(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 10),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Counsellor',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushNamed(context, '/counsellorProfile');
              },
            ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 Welcome
            const Text(
              "Welcome, Counsellor 👋",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // 🔥 Today Overview (卡片升級版)
            Container(
              width: double.infinity, // 🔥 关键：填满整行
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B6775), Color(0xFF6895C3)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Today Overview",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Appointments Today: 3",
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    "Pending: 2",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 🔥 Section Title
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // 🔥 Grid Menu（比你原本更像homepage🔥）
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: [
                _menuCard(
                  context,
                  "Appointments",
                  Icons.calendar_today,
                  const Color(0xFF4A90E2),
                  '/manageAppointments',
                ),
                _menuCard(
                  context,
                  "Students History",
                  Icons.people,
                  const Color(0xFF50B27C),
                  '/studentRecords',
                ),
              ],
            ),

            const SizedBox(height: 25),

            // 🔥 Upcoming Section（讓它像真正系統🔥）
            const Text(
              "Upcoming Appointments",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _appointmentItem("Ali", "10:00 AM"),
            _appointmentItem("Tan", "2:00 PM"),
          ],
        ),
      ),
    );
  }

  // 🔥 Menu Card
  Widget _menuCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      String route,
      ) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Appointment List Item
  Widget _appointmentItem(String name, String time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(
            time,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}