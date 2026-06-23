/// Central application configuration.
///
/// [apiBaseUrl] defaults to the production Render backend. Override at build
/// time with `--dart-define`:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// flutter build apk --dart-define=API_BASE_URL=https://api.example.com
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL of the FastAPI backend.
  /// Must NOT have a trailing slash.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://e-enrolment-and-e-counselling.onrender.com',
  );

  /// Default enrollment fee when course level is unknown.
  static const double defaultEnrollmentFee = 400.0;

  /// Enrollment fees keyed by course level (case-insensitive).
  static const Map<String, double> enrollmentFeesByLevel = {
    'diploma': 350.0,
    'bachelor': 500.0,
  };

  /// Returns the enrollment fee for a [courseLevel] string from Firestore.
  static double enrollmentFeeForLevel(String courseLevel) {
    return enrollmentFeesByLevel[courseLevel.toLowerCase()] ??
        defaultEnrollmentFee;
  }

  /// Bank transfer details shown on the student payment screen.
  static const String paymentBankName = 'Maybank';
  static const String paymentAccountName =
      'Tunku Abdul Rahman University of Management and Technology';
  static const String paymentAccountNumber = '1234567890';

  /// University name displayed on offer letters.
  static const String universityName =
      'Tunku Abdul Rahman University of Management and Technology';
}

// =============================================================================
// AppConfigException
// =============================================================================

/// Thrown when a required configuration value is missing at runtime.
class AppConfigException implements Exception {
  final String message;
  const AppConfigException(this.message);

  @override
  String toString() => 'AppConfigException: $message';
}
