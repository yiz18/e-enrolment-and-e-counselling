/// Central application configuration.
///
/// Values are injected at build time via `--dart-define`:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// flutter build apk --dart-define=API_BASE_URL=https://api.example.com
/// ```
///
/// No hardcoded `localhost` or IP addresses appear anywhere in the app code.
/// If [apiBaseUrl] is the empty string the prediction service will throw an
/// [AppConfigException] with an actionable message.
class AppConfig {
  AppConfig._();

  /// Base URL of the FastAPI backend, e.g. `http://10.0.2.2:8000`.
  /// Must NOT have a trailing slash.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
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
