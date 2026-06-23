import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'ocr_post_processor.dart';

// =============================================================================
// Exceptions
// =============================================================================

/// Thrown when the FastAPI `/ocr` endpoint returns a non-200 status.
class OcrApiException implements Exception {
  final int statusCode;
  final String body;

  const OcrApiException({required this.statusCode, required this.body});

  String get message {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // Fall through to generic message.
    }
    return 'OCR server returned HTTP $statusCode.';
  }

  @override
  String toString() => 'OcrApiException(status=$statusCode): $body';
}

/// Thrown when `/ocr` returns HTTP 200 but the JSON is missing expected fields.
class OcrParseException implements Exception {
  final String message;

  const OcrParseException(this.message);

  @override
  String toString() => 'OcrParseException: $message';
}

// =============================================================================
// Service
// =============================================================================

/// Calls the FastAPI `/ocr` endpoint for web academic document OCR.
///
/// The backend returns row-grouped fragments. This service deserialises them
/// into [OcrStructuredResult] and applies [OcrPostProcessor.refineRows] so
/// orphan grade merge and subject consolidation run before parsing.
class RemoteOcrService {
  static const _timeout = Duration(seconds: 60);

  final http.Client _client;

  RemoteOcrService({http.Client? client}) : _client = client ?? http.Client();

  /// Uploads [bytes] to `POST /ocr` and returns a refined structured result.
  Future<OcrStructuredResult> processImage(
    List<int> bytes, {
    required String filename,
  }) async {
    _assertConfigured();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/ocr');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename.isEmpty ? 'upload.jpg' : filename,
          contentType: _contentTypeForFilename(filename),
        ),
      );

    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw OcrApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return parseResponse(response.body);
  }

  /// Deserialises the `/ocr` JSON payload and applies compatibility refinements.
  static OcrStructuredResult parseResponse(String body) {
    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw OcrParseException('Response is not valid JSON.');
    }

    final rawRows = json['rows'];
    if (rawRows is! List) {
      throw const OcrParseException('Response JSON is missing "rows".');
    }

    final rows = rawRows.map((rawRow) {
      final rowMap = rawRow as Map<String, dynamic>;
      final rawFragments = rowMap['fragments'];
      if (rawFragments is! List) {
        throw const OcrParseException('Each row must contain a "fragments" list.');
      }

      final fragments = rawFragments.map((rawFragment) {
        final fragmentMap = rawFragment as Map<String, dynamic>;
        return OcrFragment(
          text: fragmentMap['text'] as String,
          top: (fragmentMap['top'] as num).toDouble(),
          bottom: (fragmentMap['bottom'] as num).toDouble(),
          left: (fragmentMap['left'] as num).toDouble(),
          right: (fragmentMap['right'] as num).toDouble(),
        );
      }).toList();

      return OcrRow(fragments);
    }).toList();

    return OcrPostProcessor.refineRows(OcrStructuredResult(rows));
  }

  static void _assertConfigured() {
    if (AppConfig.apiBaseUrl.isEmpty) {
      throw const AppConfigException(
        'API_BASE_URL is not set. '
        'Run the app with: flutter run --dart-define=API_BASE_URL=http://<host>:<port>',
      );
    }
  }

  static MediaType _contentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }
}
