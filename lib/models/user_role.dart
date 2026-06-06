/// Known user roles stored in `users/{uid}.role`.
abstract final class UserRole {
  static const String student = 'student';
  static const String admin = 'admin';
  static const String counsellor = 'counsellor';

  static const Set<String> staffRoles = {admin, counsellor};

  static String dashboardRoute(String role) {
    switch (role) {
      case admin:
        return '/adminDashboard';
      case counsellor:
        return '/counsellorDashboard';
      default:
        return '/dashboard';
    }
  }
}
