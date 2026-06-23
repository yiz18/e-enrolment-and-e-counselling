import 'dart:async';



import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:image_picker/image_picker.dart';



import '../config/app_config.dart';

import '../data/subject_catalogs.dart';

import '../models/parsed_academic_result.dart';

import '../services/academic_result_parser.dart';

import '../services/ocr_post_processor.dart';

import '../services/remote_ocr_service.dart';

import '../services/student_session.dart';

import '../services/subject_corrector.dart';

import 'parsed_academic_result_screen.dart';



class UploadDocumentScreen extends StatefulWidget {

  const UploadDocumentScreen({super.key});



  @override

  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();

}



class _UploadDocumentScreenState extends State<UploadDocumentScreen> {

  XFile? _pickedFile;

  Uint8List? _previewBytes;

  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();

  final RemoteOcrService _remoteOcrService = RemoteOcrService();



  // Parser instances are const and reused across invocations.

  static const _corrector = SubjectCorrector(subjects: kSpmSubjects);

  static const _parser = AcademicResultParser(subjectCorrector: _corrector);



  Future<void> _setPickedFile(XFile pickedFile) async {

    final bytes = await pickedFile.readAsBytes();

    if (!mounted) return;



    setState(() {

      _pickedFile = pickedFile;

      _previewBytes = bytes;

    });

  }



  Future<void> pickFromCamera() async {

    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {

      await _setPickedFile(pickedFile);

    }

  }



  Future<void> pickFromGallery() async {

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {

      await _setPickedFile(pickedFile);

    }

  }



  Future<void> _runOcr() async {

    if (_pickedFile == null || _isProcessing) return;



    setState(() => _isProcessing = true);



    try {

      final ParsedAcademicResult parsedResult =

          kIsWeb ? await _runRemoteOcr() : await _runMobileOcr();



      if (!mounted) return;



      if (!parsedResult.hasStudentInfo && !parsedResult.hasResults) {

        _showOcrSnackBar(

          'No academic results detected. Try a clearer photo.',

          showRetry: true,

        );

      } else {

        Navigator.push(

          context,

          MaterialPageRoute(

            builder: (_) =>

                ParsedAcademicResultScreen(parsedResult: parsedResult),

          ),

        );

      }

    } catch (e) {

      if (!mounted) return;

      _showOcrSnackBar(_friendlyOcrError(e), showRetry: true);

    } finally {

      if (mounted) setState(() => _isProcessing = false);

    }

  }



  Future<ParsedAcademicResult> _runMobileOcr() async {

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);



    try {

      final inputImage = InputImage.fromFilePath(_pickedFile!.path);

      final RecognizedText recognizedText =

          await textRecognizer.processImage(inputImage);



      final OcrStructuredResult structuredResult =

          OcrPostProcessor.process(recognizedText);



      return _parser.parse(structuredResult);

    } finally {

      await textRecognizer.close();

    }

  }



  Future<ParsedAcademicResult> _runRemoteOcr() async {

    final bytes = _previewBytes ?? await _pickedFile!.readAsBytes();

    final structuredResult = await _remoteOcrService.processImage(

      bytes,

      filename: _pickedFile!.name,

    );

    return _parser.parse(structuredResult);

  }



  void _showOcrSnackBar(String message, {required bool showRetry}) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

        action: showRetry

            ? SnackBarAction(

                label: 'Retry',

                onPressed: () {

                  if (!_isProcessing && _pickedFile != null) {

                    _runOcr();

                  }

                },

              )

            : null,

      ),

    );

  }



  String _friendlyOcrError(Object error) {

    if (error is AppConfigException) {

      return 'OCR server is not configured. Set API_BASE_URL and try again.';

    }

    if (error is OcrApiException) {

      if (error.statusCode == 503) {

        return 'OCR service is temporarily unavailable. Please try again later.';

      }

      return error.message;

    }

    if (error is OcrParseException) {

      return 'OCR response was invalid. Please try again.';

    }

    if (error is TimeoutException) {

      return 'OCR request timed out. Check your connection and try again.';

    }

    return 'OCR failed. Please try again with a clearer photo.';

  }



  bool get _canRunOcr => _pickedFile != null && !_isProcessing;



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(

        title: const Text('Upload Document'),

        elevation: 0,

        backgroundColor: Colors.blueAccent,

        foregroundColor: Colors.black,

      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Align(

          alignment: Alignment.topCenter,

          child: Container(

            constraints: const BoxConstraints(maxWidth: 500),

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(16),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity(0.08),

                  blurRadius: 15,

                  offset: const Offset(0, 6),

                ),

              ],

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const StudentSessionBanner(),

                const SizedBox(height: 16),

                const Text(

                  'Upload your academic document',

                  style: TextStyle(

                    fontSize: 18,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                const SizedBox(height: 20),



                if (_previewBytes != null)

                  Container(

                    height: 180,

                    width: double.infinity,

                    margin: const EdgeInsets.only(bottom: 16),

                    clipBehavior: Clip.hardEdge,

                    decoration: BoxDecoration(

                      borderRadius: BorderRadius.circular(12),

                    ),

                    child: Image.memory(

                      _previewBytes!,

                      fit: BoxFit.cover,

                      width: double.infinity,

                      height: 180,

                    ),

                  ),



                if (kIsWeb) ...[

                  Padding(

                    padding: const EdgeInsets.only(bottom: 16),

                    child: Text(

                      'On web, your document is processed by the OCR server '

                      '(${AppConfig.apiBaseUrl}).',

                      style: const TextStyle(

                        fontSize: 13,

                        color: Colors.blueGrey,

                      ),

                    ),

                  ),

                ],



                SizedBox(

                  width: double.infinity,

                  child: ElevatedButton.icon(

                    onPressed: _isProcessing ? null : pickFromGallery,

                    icon: const Icon(Icons.upload_file),

                    label: const Text('Choose File'),

                  ),

                ),



                const SizedBox(height: 12),



                if (!kIsWeb) ...[

                  SizedBox(

                    width: double.infinity,

                    child: ElevatedButton.icon(

                      onPressed: _isProcessing ? null : pickFromCamera,

                      icon: const Icon(Icons.camera_alt),

                      label: const Text('Take Photo'),

                    ),

                  ),

                  const SizedBox(height: 20),

                ] else

                  const SizedBox(height: 20),



                SizedBox(

                  width: double.infinity,

                  child: ElevatedButton(

                    onPressed: _canRunOcr ? _runOcr : null,

                    child: _isProcessing

                        ? const SizedBox(

                            height: 20,

                            width: 20,

                            child: CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Colors.white,

                            ),

                          )

                        : const Text('Upload & Process OCR'),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}


