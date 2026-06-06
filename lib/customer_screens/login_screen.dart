import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateForRole(String role) async {
    Navigator.pushReplacementNamed(context, UserRole.dashboardRoute(role));
  }

  Future<void> _runStudentAuth(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (!mounted) return;
      await _navigateForRole(UserRole.student);
    } catch (e) {
      if (!mounted) return;
      if (e is AuthCancelledException) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    await _runStudentAuth(
      () => _authService.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> _signInStaff(String expectedRole) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profile = await _authService.signInStaff(
        email: email,
        password: password,
        expectedRole: expectedRole,
      );
      if (!mounted) return;
      await _navigateForRole(profile.role);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      await _navigateForRole(UserRole.student);
    } catch (e) {
      if (!mounted) return;
      if (e is AuthCancelledException) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role =
        ModalRoute.of(context)?.settings.arguments as String? ?? UserRole.student;
    final isStudent = role == UserRole.student;
    final isBusy = _isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: isBusy
                          ? null
                          : () {
                              Navigator.pushReplacementNamed(context, '/role');
                            },
                    ),
                    Text(
                      '${role.toUpperCase()} Login',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome Back 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                const Text('Email'),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !isBusy,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Password'),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !isBusy,
                  onSubmitted: (_) {
                    if (isStudent) {
                      _signInWithEmail();
                    } else {
                      _signInStaff(role);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            if (isStudent) {
                              _signInWithEmail();
                            } else {
                              _signInStaff(role);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (isStudent) ...[
                  const SizedBox(height: 24),
                  const AuthDivider(),
                  const SizedBox(height: 24),
                  GoogleSignInButton(
                    onPressed: _signInWithGoogle,
                    isLoading: _isGoogleLoading,
                  ),
                ],
                const SizedBox(height: 20),
                if (isStudent)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: isBusy
                            ? null
                            : () {
                                Navigator.pushNamed(context, '/register');
                              },
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
