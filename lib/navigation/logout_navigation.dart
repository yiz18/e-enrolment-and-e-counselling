import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Signs the user out and returns to the role selection screen.
///
/// Clears the navigation stack so protected dashboards cannot be reached
/// via the browser back button after logout.
Future<void> logoutToRoleSelection(BuildContext context) async {
  await AuthService().signOut();
  if (!context.mounted) return;
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/role',
    (route) => false,
  );
}
