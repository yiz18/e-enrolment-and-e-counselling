import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

/// Uploads images to Cloudinary using unsigned upload presets.
class CloudinaryService {
  static const _uploadTimeout = Duration(seconds: 60);

  /// Uploads a local [file] and returns the Cloudinary `secure_url`.
  static Future<String> uploadImage(File file) async {
    if (!await file.exists()) {
      throw ArgumentError('Image file does not exist: ${file.path}');
    }

    final bytes = await file.readAsBytes();
    final filename = file.path.split(Platform.pathSeparator).last;
    return _uploadImageBytes(bytes, filename);
  }

  /// Uploads a picked [file] from [ImagePicker] on any platform, including web.
  static Future<String> uploadXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ArgumentError('Image file is empty.');
    }

    final filename = file.name.trim().isNotEmpty ? file.name : 'upload.jpg';
    return _uploadImageBytes(bytes, filename);
  }

  static Future<String> _uploadImageBytes(
    List<int> bytes,
    String filename,
  ) async {
    final uploadUrl =
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload';

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    final streamedResponse = await request.send().timeout(
      _uploadTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Cloudinary upload timed out after 60 seconds',
        );
      },
    );

    final response = await http.Response.fromStream(streamedResponse).timeout(
      _uploadTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Cloudinary response read timed out after 60 seconds',
        );
      },
    );

    if (response.statusCode != 200) {
      throw CloudinaryUploadException(
        'Upload failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = body['secure_url'] as String?;

    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw CloudinaryUploadException(
        'Upload succeeded but secure_url was missing from the response.',
      );
    }

    debugPrint('Cloudinary secure_url: $secureUrl');
    return secureUrl;
  }

  /// Uploads a payment receipt image or PDF and returns the Cloudinary URL.
  ///
  /// Images use the `image` resource type; PDFs use `raw`.
  static Future<String> uploadReceipt(File file) async {
    if (!await file.exists()) {
      throw ArgumentError('Receipt file does not exist: ${file.path}');
    }

    final lowerPath = file.path.toLowerCase();
    final isPdf = lowerPath.endsWith('.pdf');
    final resourceType = isPdf ? 'raw' : 'image';

    final uploadUrl =
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/$resourceType/upload';

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(
      _uploadTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Cloudinary upload timed out after 60 seconds',
        );
      },
    );

    final response = await http.Response.fromStream(streamedResponse).timeout(
      _uploadTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Cloudinary response read timed out after 60 seconds',
        );
      },
    );

    if (response.statusCode != 200) {
      throw CloudinaryUploadException(
        'Upload failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = body['secure_url'] as String?;

    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw CloudinaryUploadException(
        'Upload succeeded but secure_url was missing from the response.',
      );
    }

    return secureUrl;
  }
}

/// Raised when Cloudinary returns a non-success response or malformed payload.
class CloudinaryUploadException implements Exception {
  CloudinaryUploadException(this.message);

  final String message;

  @override
  String toString() => 'CloudinaryUploadException: $message';
}
