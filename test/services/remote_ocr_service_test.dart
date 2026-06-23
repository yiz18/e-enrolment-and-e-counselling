import 'package:e_enrolment_and_e_counselling_appication/config/app_config.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/ocr_post_processor.dart';
import 'package:e_enrolment_and_e_counselling_appication/services/remote_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteOcrService.parseResponse', () {
    test('deserialises rows and applies refineRows', () {
      const body = '''
{
  "rows": [
    {
      "fragments": [
        {"text": "C", "top": 100, "bottom": 120, "left": 300, "right": 320},
        {"text": "(KEPUJIAN)", "top": 100, "bottom": 120, "left": 330, "right": 420}
      ]
    },
    {
      "fragments": [
        {"text": "ADDITIONAL", "top": 130, "bottom": 150, "left": 50, "right": 180},
        {"text": "MATHEMATICS", "top": 130, "bottom": 150, "left": 190, "right": 320}
      ]
    }
  ]
}
''';

      final structured = RemoteOcrService.parseResponse(body);

      expect(structured.rows.length, 1);
      expect(structured.rows.first.text, contains('ADDITIONAL MATHEMATICS'));
      expect(structured.rows.first.text, contains('C'));
    });

    test('throws OcrParseException when rows are missing', () {
      expect(
        () => RemoteOcrService.parseResponse('{"status":"ok"}'),
        throwsA(isA<OcrParseException>()),
      );
    });
  });

  group('OcrApiException', () {
    test('extracts detail message from JSON body', () {
      const error = OcrApiException(
        statusCode: 503,
        body: '{"detail":"OCR engine is not available on this server."}',
      );

      expect(error.message, contains('OCR engine is not available'));
    });
  });

  group('AppConfig', () {
    test('apiBaseUrl has a default production value', () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
    });
  });
}
