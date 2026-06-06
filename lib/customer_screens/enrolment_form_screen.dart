import 'package:flutter/material.dart';

class EnrolmentFormScreen extends StatefulWidget {
  const EnrolmentFormScreen({super.key});

  @override
  State<EnrolmentFormScreen> createState() =>
      _EnrolmentFormScreenState();
}

class _EnrolmentFormScreenState
    extends State<EnrolmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? name;
  String? ic;
  String? email;
  String? phone;
  String? programme;
  String? intake;

  final programmes = [
    "Software Engineering",
    "Data Science",
    "Information Systems",
  ];

  final intakes = [
    "May 2026",
    "October 2026",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Enrolment Form"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
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

            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Student Information",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    decoration: const InputDecoration(labelText: "Full Name"),
                    onSaved: (v) => name = v,
                  ),

                  TextFormField(
                    decoration: const InputDecoration(labelText: "IC / Passport"),
                    onSaved: (v) => ic = v,
                  ),

                  TextFormField(
                    decoration: const InputDecoration(labelText: "Email"),
                    onSaved: (v) => email = v,
                  ),

                  TextFormField(
                    decoration: const InputDecoration(labelText: "Phone"),
                    onSaved: (v) => phone = v,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Application Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    hint: const Text("Select Programme"),
                    items: programmes
                        .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    ))
                        .toList(),
                    onChanged: (v) => programme = v,
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    hint: const Text("Select Intake"),
                    items: intakes
                        .map((i) => DropdownMenuItem(
                      value: i,
                      child: Text(i),
                    ))
                        .toList(),
                    onChanged: (v) => intake = v,
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _formKey.currentState!.save();

                        Navigator.pushNamed(context, '/upload');

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Application Submitted"),
                          ),
                        );
                      },
                      child: const Text("Submit Application"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}