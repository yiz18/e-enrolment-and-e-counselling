import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

// =============================================================================
// Exceptions
// =============================================================================

/// Thrown when the FastAPI /predict endpoint returns a non-200 status.
class PredictionApiException implements Exception {
  final int statusCode;
  final String body;

  const PredictionApiException({required this.statusCode, required this.body});

  @override
  String toString() =>
      'PredictionApiException(status=$statusCode): $body';
}

/// Thrown when the response JSON is well-formed HTTP 200 but missing
/// the `top3_codes` field, or the field contains unexpected data.
class PredictionParseException implements Exception {
  final String message;
  const PredictionParseException(this.message);

  @override
  String toString() => 'PredictionParseException: $message';
}

// =============================================================================
// Service
// =============================================================================

/// Calls the FastAPI `/predict` endpoint with the student's 48 RIASEC
/// questionnaire item scores and returns the model's top-3 Holland codes.
///
/// ## Request (POST /predict)
/// ```json
/// {
///   "R1": 4, "R2": 3, "R3": 5, "R4": 2, "R5": 4, "R6": 3, "R7": 5, "R8": 2,
///   "I1": 3, ...
///   "C8": 4
/// }
/// ```
/// Each value is a Likert integer in [1, 5].
///
/// ## Response
/// ```json
/// {
///   "dominant_code": "I",
///   "top3_codes": ["I", "E", "S"],
///   "probabilities": { "R": 0.08, "I": 0.41, "A": 0.07,
///                      "S": 0.18, "E": 0.20, "C": 0.06 }
/// }
/// ```
///
/// ## Error handling
/// | Condition | Thrown |
/// |-----------|--------|
/// | [AppConfig.apiBaseUrl] is empty | [AppConfigException] |
/// | Network / socket error | [SocketException] / [http.ClientException] |
/// | HTTP status ≠ 200 | [PredictionApiException] |
/// | Response missing `top3_codes` | [PredictionParseException] |
class RiasecPredictionService {
  /// Timeout applied to the POST request.
  static const _timeout = Duration(seconds: 30);

  /// The shared [http.Client] instance.  Exposed so tests can inject a mock.
  final http.Client _client;

  RiasecPredictionService({http.Client? client})
      : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sends [answers] to `POST /predict` and returns the ordered top-3
  /// Holland codes predicted by the model.
  ///
  /// [answers] must be a `Map<String, int>` with exactly 48 keys
  /// (`R1`–`R8`, `I1`–`I8`, …, `C1`–`C8`), values in [1, 5].
  /// Use the map returned by [RiasecQuestionnaireScreen] directly.
  ///
  /// Returns a `List<String>` of length 3, e.g. `["I", "E", "S"]`.
  ///
  /// Throws [AppConfigException], [PredictionApiException],
  /// [PredictionParseException], or network-level exceptions on failure.
  Future<List<String>> predict(Map<String, int> answers) async {
    _assertConfigured();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/predict');

    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
          },
          body: jsonEncode(answers),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw PredictionApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return _parseTop3(response.body);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _assertConfigured() {
    if (AppConfig.apiBaseUrl.isEmpty) {
      throw const AppConfigException(
        'API_BASE_URL is not set. '
        'Run the app with: flutter run --dart-define=API_BASE_URL=http://<host>:<port>',
      );
    }
  }

  List<String> _parseTop3(String body) {
    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw PredictionParseException('Response is not valid JSON: $body');
    }

    final raw = json['top3_codes'];
    if (raw == null) {
      throw const PredictionParseException(
        'Response JSON is missing the "top3_codes" field.',
      );
    }
    if (raw is! List) {
      throw PredictionParseException(
        '"top3_codes" must be a JSON array, got: ${raw.runtimeType}',
      );
    }

    final codes = raw.whereType<String>().toList();
    if (codes.length != 3) {
      throw PredictionParseException(
        '"top3_codes" must contain exactly 3 strings, got: $raw',
      );
    }

    return codes;
  }
}
