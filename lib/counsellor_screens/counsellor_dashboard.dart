import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../navigation/logout_navigation.dart';
import '../services/appointment_service.dart';
import '../widgets/appointment_status_chip.dart';

class CounsellorDashboardScreen extends StatelessWidget {
  const CounsellorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appointmentService = AppointmentService();

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
            const Text(
              "Welcome, Counsellor 👋",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (user == null)
              _buildStaticSections(
                context,
                appointmentsToday: 0,
                pendingCount: 0,
                upcoming: const [],
                isLoading: false,
                hasError: false,
              )
            else
              StreamBuilder<List<AppointmentModel>>(
                stream:
                    appointmentService.watchAppointmentsByCounsellor(user.uid),
                builder: (context, snapshot) {
                  final isLoading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final hasError = snapshot.hasError;
                  final dashboardData = _AppointmentDashboardData.from(
                    snapshot.data ?? const [],
                  );

                  return _buildStaticSections(
                    context,
                    appointmentsToday: dashboardData.appointmentsTodayCount,
                    pendingCount: dashboardData.pendingCount,
                    upcoming: dashboardData.upcoming,
                    isLoading: isLoading,
                    hasError: hasError,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticSections(
    BuildContext context, {
    required int appointmentsToday,
    required int pendingCount,
    required List<AppointmentModel> upcoming,
    required bool isLoading,
    required bool hasError,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _todayOverviewCard(
          appointmentsToday: appointmentsToday,
          pendingCount: pendingCount,
          isLoading: isLoading,
          hasError: hasError,
        ),
        const SizedBox(height: 25),
        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
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
        const Text(
          "Upcoming Appointments",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (hasError)
          Text(
            'Failed to load appointments.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else if (upcoming.isEmpty)
          Text(
            'No upcoming appointments',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...upcoming.map(_appointmentItem),
      ],
    );
  }

  Widget _todayOverviewCard({
    required int appointmentsToday,
    required int pendingCount,
    required bool isLoading,
    required bool hasError,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B6775), Color(0xFF6895C3)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today Overview",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (hasError)
            const Text(
              'Unable to load overview.',
              style: TextStyle(color: Colors.white),
            )
          else ...[
            Text(
              'Appointments Today: $appointmentsToday',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Pending: $pendingCount',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _appointmentItem(AppointmentModel appointment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(appointment.studentName),
          ),
          Text(
            appointment.appointmentTime,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          AppointmentStatusChip(status: appointment.status),
        ],
      ),
    );
  }
}

class _AppointmentDashboardData {
  final int appointmentsTodayCount;
  final int pendingCount;
  final List<AppointmentModel> upcoming;

  const _AppointmentDashboardData({
    required this.appointmentsTodayCount,
    required this.pendingCount,
    required this.upcoming,
  });

  static bool _isUpcomingActionableStatus(AppointmentStatus status) =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.approved;

  static _AppointmentDashboardData from(List<AppointmentModel> appointments) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var appointmentsTodayCount = 0;
    var pendingCount = 0;
    final upcomingCandidates = <AppointmentModel>[];

    for (final appointment in appointments) {
      if (appointment.status == AppointmentStatus.pending) {
        pendingCount++;
      }

      final localDate = appointment.appointmentDate.toLocal();
      final dateOnly =
          DateTime(localDate.year, localDate.month, localDate.day);

      if (dateOnly == today &&
          (appointment.status == AppointmentStatus.pending ||
              appointment.status == AppointmentStatus.approved ||
              appointment.status == AppointmentStatus.completed)) {
        appointmentsTodayCount++;
      }

      if (!dateOnly.isBefore(today) &&
          _isUpcomingActionableStatus(appointment.status)) {
        upcomingCandidates.add(appointment);
      }
    }

    upcomingCandidates.sort((a, b) {
      final dateCompare = a.appointmentDate.compareTo(b.appointmentDate);
      if (dateCompare != 0) return dateCompare;
      return a.appointmentTime.compareTo(b.appointmentTime);
    });

    return _AppointmentDashboardData(
      appointmentsTodayCount: appointmentsTodayCount,
      pendingCount: pendingCount,
      upcoming: upcomingCandidates.take(5).toList(),
    );
  }
}
