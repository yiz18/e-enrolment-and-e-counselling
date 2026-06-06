import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';

/// Displays full course information and lets the signed-in student apply once.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _applicationService = ApplicationService();
  final _authService = AuthService();

  bool _isCheckingStatus = true;
  bool _hasApplied = false;
  bool _isApplying = false;
  bool _statusLoaded = false;
  Course? _course;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _course ??= ModalRoute.of(context)?.settings.arguments as Course?;
    if (!_statusLoaded) {
      _statusLoaded = true;
      _loadApplicationStatus();
    }
  }

  Future<void> _loadApplicationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    final course = _course;

    if (user == null || course == null) {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _hasApplied = false;
        });
      }
      return;
    }

    try {
      final applied = await _applicationService.hasApplied(
        userId: user.uid,
        courseId: course.id,
      );
      if (mounted) {
        setState(() {
          _hasApplied = applied;
          _isCheckingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  Future<void> _applyForCourse() async {
    final user = FirebaseAuth.instance.currentUser;
    final course = _course;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to apply for a course.')),
      );
      return;
    }

    if (course == null || _hasApplied || _isApplying) return;

    setState(() => _isApplying = true);

    try {
      final profile = await _authService.getCurrentAppUser();
      final studentName =
          profile?.fullName ?? user.displayName ?? 'Student';
      final studentEmail = profile?.email ?? user.email ?? '';

      await _applicationService.applyForCourse(
        userId: user.uid,
        studentName: studentName,
        studentEmail: studentEmail,
        courseId: course.id,
        courseCode: course.code,
        courseName: course.name,
      );

      if (!mounted) return;

      setState(() {
        _hasApplied = true;
        _isApplying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application submitted for ${course.name}.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on StateError {
      if (!mounted) return;
      setState(() {
        _hasApplied = true;
        _isApplying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already applied for this course.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit application: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    final user = FirebaseAuth.instance.currentUser;
    final canApply = user != null && !_hasApplied && !_isCheckingStatus;

    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course Details')),
        body: const Center(child: Text('Course not found.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Course Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.faculty,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Code: ${course.code}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Level: ${course.level}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (course.interestTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Interest areas',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: course.interestTags
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor:
                                      Colors.blueAccent.withValues(alpha: 0.08),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canApply && !_isApplying ? _applyForCourse : null,
                    child: _isCheckingStatus || _isApplying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_hasApplied ? 'Already Applied' : 'Apply Now'),
                  ),
                ),
                if (user == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to apply for this course.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
