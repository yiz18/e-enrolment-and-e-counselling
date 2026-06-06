import 'package:flutter/material.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime? selectedDate;
  int selectedIndex = -1;
  String? selectedMode;
  String? selectedReason;

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

      // ✅ 关键修正在这里
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter, // 🔥 不再垂直居中
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

                // 📅 DATE
                const Text("Select Date"),
                const SizedBox(height: 8),

                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );

                    if (date != null) {
                      setState(() => selectedDate = date);
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

                // ⏰ TIME
                const Text("Select Time Slot"),
                const SizedBox(height: 10),

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

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedIndex = index);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeSlots[index],
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
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

                // 📍 MODE
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

                // 📝 REASON
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

                // ✅ BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedDate == null ||
                        selectedIndex == -1 ||
                        selectedMode == null ||
                        selectedReason == null)
                        ? null
                        : () {
                      // TODO: submit booking
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Book Appointment"),
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