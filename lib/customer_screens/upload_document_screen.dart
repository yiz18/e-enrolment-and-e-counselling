import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

import '../data/subject_catalogs.dart';
import '../services/academic_result_parser.dart';
import '../services/ocr_post_processor.dart';
import '../services/student_session.dart';
import '../services/subject_corrector.dart';
import 'parsed_academic_result_screen.dart';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _image;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  // Parser instances are const and reused across invocations.
  static const _corrector = SubjectCorrector(subjects: kSpmSubjects);
  static const _parser = AcademicResultParser(subjectCorrector: _corrector);

  Future<void> pickFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> pickFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _runOcr() async {
    if (_image == null) return;

    setState(() => _isProcessing = true);

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(_image!.path);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      if (!mounted) return;

      final OcrStructuredResult structuredResult =
          OcrPostProcessor.process(recognizedText);

      final parsedResult = _parser.parse(structuredResult);

      if (!parsedResult.hasStudentInfo && !parsedResult.hasResults) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "No academic results detected. Try a clearer photo."),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OCR failed: ${e.toString()}")),
      );
    } finally {
      await textRecognizer.close();
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Upload Document"),
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
                  "Upload your academic document",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Image preview
                if (_image != null)
                  Container(
                    height: 180,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_image!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                // Choose File
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : pickFromGallery,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Choose File"),
                  ),
                ),

                const SizedBox(height: 12),

                // Take Photo
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Take Photo"),
                  ),
                ),

                const SizedBox(height: 20),

                // Upload & Process OCR
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_image == null || _isProcessing) ? null : _runOcr,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Upload & Process OCR"),
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
