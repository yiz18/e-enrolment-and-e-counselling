import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../services/staff_service.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _appointmentService = AppointmentService();
  final _authService = AuthService();
  final _staffService = StaffService();

  AppUser? selectedCounsellor;
  DateTime? selectedDate;
  int selectedIndex = -1;
  String? selectedMode;
  String? selectedReason;
  bool _isSubmitting = false;
  bool _loadingCounsellors = true;
  bool _loadingOccupiedSlots = false;
  bool _showCounsellorValidation = false;
  Set<String> _occupiedTimeSlots = {};
  List<AppUser> _counsellors = [];

  final List<String> timeSlots = [
    "9:00 AM",
    "10:00 AM",
    "11:00 AM",
    "1:00 PM",
    "2:00 PM",
    "3:00 PM",
  ];

  final List<String> reasons = [
    "Academic concerns",
    "Anxiety",
    "Family issues",
    "Relationship issues",
    "Time management",
    "Career plans",
    "Financial issues",
  ];

  bool get _canSubmit =>
      selectedCounsellor != null &&
      selectedDate != null &&
      selectedIndex != -1 &&
      selectedMode != null &&
      selectedReason != null;

  @override
  void initState() {
    super.initState();
    _loadCounsellors();
  }

  Future<void> _loadCounsellors() async {
    setState(() => _loadingCounsellors = true);

    try {
      final counsellors = await _staffService.getActiveCounsellors();
      if (!mounted) return;
      setState(() {
        _counsellors = counsellors;
        _loadingCounsellors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCounsellors = false);
    }
  }

  void _clearForm() {
    setState(() {
      selectedDate = null;
      selectedIndex = -1;
      selectedMode = null;
      selectedReason = null;
      _occupiedTimeSlots = {};
      _loadingOccupiedSlots = false;
      _showCounsellorValidation = false;
    });
  }

  Future<void> _loadOccupiedSlots() async {
    final counsellor = selectedCounsellor;
    final date = selectedDate;
    if (counsellor == null || date == null) return;

    setState(() {
      _loadingOccupiedSlots = true;
      _occupiedTimeSlots = {};
      selectedIndex = -1;
    });

    try {
      final appointmentDate = DateTime(date.year, date.month, date.day);
      final occupied = await _appointmentService.getOccupiedTimeSlots(
        counsellorId: counsellor.uid,
        appointmentDate: appointmentDate,
      );

      if (!mounted) return;
      setState(() {
        _occupiedTimeSlots = occupied;
        _loadingOccupiedSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOccupiedSlots = false);
    }
  }

  void _requireCounsellorSelection() {
    if (selectedCounsellor == null) {
      setState(() => _showCounsellorValidation = true);
    }
  }

  String _bookingErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to book an appointment.';
        case 'unavailable':
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        default:
          return error.message ?? 'Failed to book appointment. Please try again.';
      }
    }

    return 'Failed to book appointment. Please try again.';
  }

  Future<void> _submitBooking() async {
    if (selectedCounsellor == null) {
      setState(() => _showCounsellorValidation = true);
      return;
    }

    if (!_canSubmit || _isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to book an appointment.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final profile = await _authService.getCurrentAppUser();
      final studentName =
          profile?.fullName ?? user.displayName ?? 'Student';

      final counsellor = selectedCounsellor!;
      final appointmentDate = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );

      final appointmentTime = timeSlots[selectedIndex];
      final counsellorName = counsellor.fullName;
      final appointmentDateLabel = appointmentDate.toString().split(' ')[0];

      final hasConflict = await _appointmentService.hasSlotConflict(
        counsellorId: counsellor.uid,
        appointmentDate: appointmentDate,
        appointmentTime: appointmentTime,
      );

      if (hasConflict) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This time slot is unavailable. Please select another slot.',
            ),
          ),
        );
        await _loadOccupiedSlots();
        return;
      }

      await _appointmentService.createAppointment(
        studentId: user.uid,
        studentName: studentName,
        counsellorId: counsellor.uid,
        counsellorName: counsellorName,
        appointmentDate: appointmentDate,
        appointmentTime: appointmentTime,
        mode: selectedMode!,
        reason: selectedReason!,
      );

      if (!mounted) return;

      _clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment booked with $counsellorName on '
            '$appointmentDateLabel at $appointmentTime.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_bookingErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Appointment"),
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
                  "Book Appointment",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Counsellor
                const Text("Counsellor"),
                const SizedBox(height: 8),

                if (_loadingCounsellors)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_counsellors.isEmpty)
                  Text(
                    'No counsellors are available right now.',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: _showCounsellorValidation &&
                              selectedCounsellor == null
                          ? Border.all(color: Colors.red.shade400)
                          : null,
                    ),
                    child: DropdownButtonFormField<AppUser>(
                      value: selectedCounsellor,
                      hint: const Text("Select a counsellor"),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      items: _counsellors.map((counsellor) {
                        return DropdownMenuItem(
                          value: counsellor,
                          child: Text(counsellor.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCounsellor = value;
                          _showCounsellorValidation = false;
                          selectedIndex = -1;
                          _occupiedTimeSlots = {};
                        });
                        if (value != null && selectedDate != null) {
                          _loadOccupiedSlots();
                        }
                      },
                    ),
                  ),

                if (_showCounsellorValidation && selectedCounsellor == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Please select a counsellor.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Date
                const Text("Select Date"),
                const SizedBox(height: 8),

                GestureDetector(
                  onTap: () async {
                    if (selectedCounsellor == null) {
                      _requireCounsellorSelection();
                      return;
                    }

                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );

                    if (date != null) {
                      setState(() => selectedDate = date);
                      await _loadOccupiedSlots();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      selectedDate == null
                          ? "Choose a date"
                          : selectedDate.toString().split(" ")[0],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Time
                const Text("Select Time Slot"),
                const SizedBox(height: 10),

                if (_loadingOccupiedSlots &&
                    selectedDate != null &&
                    selectedCounsellor != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: timeSlots.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.5,
                  ),
                  itemBuilder: (context, index) {
                    final isSelected = selectedIndex == index;
                    final slot = timeSlots[index];
                    final isOccupied = _occupiedTimeSlots.contains(slot);
                    final slotsUnavailable =
                        selectedCounsellor == null || selectedDate == null;
                    final isDisabled =
                        isOccupied || _loadingOccupiedSlots || slotsUnavailable;

                    return GestureDetector(
                      onTap: isDisabled
                          ? () {
                              if (selectedCounsellor == null) {
                                _requireCounsellorSelection();
                              }
                            }
                          : () {
                              setState(() => selectedIndex = index);
                            },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDisabled
                              ? Colors.grey.shade300
                              : isSelected
                                  ? Colors.blueAccent
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          slot,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDisabled
                                ? Colors.grey.shade600
                                : isSelected
                                    ? Colors.white
                                    : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Mode
                const Text("Mode"),
                Row(
                  children: [
                    Radio(
                      value: "Online",
                      groupValue: selectedMode,
                      onChanged: (value) {
                        setState(() => selectedMode = value);
                      },
                    ),
                    const Text("Online"),

                    Radio(
                      value: "Face-to-Face",
                      groupValue: selectedMode,
                      onChanged: (value) {
                        setState(() => selectedMode = value);
                      },
                    ),
                    const Text("Face-to-Face"),
                  ],
                ),

                const SizedBox(height: 20),

                // Reason
                const Text("Reason"),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedReason,
                    hint: const Text("Select a reason"),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    items: reasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedReason = value);
                    },
                  ),
                ),

                const SizedBox(height: 30),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _canSubmit && !_isSubmitting ? _submitBooking : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Book Appointment"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
