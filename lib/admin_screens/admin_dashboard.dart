import 'package:flutter/material.dart';

import '../navigation/logout_navigation.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 768)
            // Web: user dropdown menu
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'logout') {
                  logoutToRoleSelection(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            )
          else
            // Mobile: original icon, original behaviour
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushNamed(context, '/adminProfile');
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
              "Welcome Admin 👋",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // 🔥 SUMMARY CARDS
            Row(
              children: [
                _summaryCard("Pending", "12", Colors.orange),
                const SizedBox(width: 10),
                _summaryCard("Approved", "30", Colors.green),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                _summaryCard("Payments", "45", Colors.purple),
              ],
            ),

            const SizedBox(height: 30),

            // 🔥 QUICK ACTIONS
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // 🔥 椭圆按钮（重点）
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ovalActionButton(
                  context,
                  "Applications",
                  Icons.description,
                  '/manageApplications',
                ),
                const SizedBox(width: 20),
                _ovalActionButton(
                  context,
                  "Reports",
                  Icons.bar_chart,
                  '/reports',
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 🔥 RECENT APPLICATIONS
            const Text(
              "Recent Applications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _applicationItem("Ali", "Pending"),
            _applicationItem("Tan", "Approved"),
            _applicationItem("Kumar", "Pending"),

          ],
        ),
      ),
    );
  }

  // 🔥 Summary Card
  Widget _summaryCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(title),
          ],
        ),
      ),
    );
  }

  // 🔥 椭圆按钮
  Widget _ovalActionButton(
      BuildContext context,
      String title,
      IconData icon,
      String route,
      ) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Application List Item
  Widget _applicationItem(String name, String status) {
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
            status,
            style: TextStyle(
              color: status == "Pending" ? Colors.orange : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}