import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/academic_result_entry.dart';
import '../models/chat_message.dart';
import '../models/course_fit_result.dart';
import '../models/student_interest.dart';
import '../services/student_result_service.dart';

// =============================================================================
// RIASEC code → human-readable label
// =============================================================================

const Map<String, String> _riasecLabels = {
  'R': 'Realistic (hands-on, practical)',
  'I': 'Investigative (analytical, intellectual)',
  'A': 'Artistic (creative, expressive)',
  'S': 'Social (helping, teaching)',
  'E': 'Enterprising (leading, persuading)',
  'C': 'Conventional (organizing, detail-oriented)',
};

// =============================================================================
// ChatbotService
// =============================================================================

/// Manages the AI counselling chatbot powered by Google Gemini.
///
/// ### Responsibilities
/// 1. Build a personalised system prompt from the student's RIASEC profile,
///    recommended courses, and academic strengths.
/// 2. Maintain a [ChatSession] so Gemini retains conversation history.
/// 3. Persist every exchange to Firestore under
///    `chatHistory/{userId}/messages`.
///
/// ### Usage
/// ```dart
/// final svc = ChatbotService(userId: uid, apiKey: 'YOUR_KEY');
/// await svc.initialise(rankedCourses: fitted, studentInterest: interest);
/// final reply = await svc.sendMessage('Why is CS recommended for me?');
/// ```
class ChatbotService {
  // Gemini model name — Flash is fast and cost-efficient for chat.
  static const _modelName = 'gemini-2.5-flash';

  static const _apiKey = String.fromEnvironment('CHATBOT_API_KEY');

  final String userId;
  final FirebaseFirestore _db;

  late final GenerativeModel _model;
  late ChatSession _chat;
  late final String _sessionId;

  bool _initialised = false;

  ChatbotService({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Builds the system prompt and starts a new [ChatSession].
  ///
  /// Must be called once before [sendMessage].
  Future<void> initialise({
    required List<CourseFitResult> rankedCourses,
    required StudentInterest? studentInterest,
    StudentResultRecord? studentRecord,
  }) async {
    final systemPrompt =
        _buildSystemPrompt(rankedCourses, studentInterest, studentRecord);

    if (_apiKey.isEmpty) {
      throw StateError(
        'CHATBOT_API_KEY is not configured. '
        'Run the app with: flutter run --dart-define=CHATBOT_API_KEY=<your-key>',
      );
    }

    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );

    _chat = _model.startChat();
    _initialised = true;
  }

  // ---------------------------------------------------------------------------
  // Send a message
  // ---------------------------------------------------------------------------

  /// Sends [userText] to Gemini and returns the model's reply.
  ///
  /// Both the user message and the bot reply are saved to Firestore.
  Future<String> sendMessage(String userText) async {
    if (!_initialised) {
      throw StateError('ChatbotService.initialise() must be called first.');
    }

    // 1. Persist user message
    final userMsg = ChatMessage.user(text: userText, sessionId: _sessionId);
    await _saveMessage(userMsg);

    // 2. Send to Gemini
    final response = await _chat.sendMessage(Content.text(userText));
    final replyText =
        response.text?.trim() ?? 'I apologise, I could not generate a reply.';

    // 3. Persist bot reply
    final botMsg = ChatMessage.bot(text: replyText, sessionId: _sessionId);
    await _saveMessage(botMsg);

    return replyText;
  }

  // ---------------------------------------------------------------------------
  // Load existing chat history
  // ---------------------------------------------------------------------------

  /// Returns the last [limit] messages for this student, ordered oldest first.
  Future<List<ChatMessage>> loadHistory({int limit = 50}) async {
    final snap = await _db
        .collection('chatHistory')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map(ChatMessage.fromFirestore)
        .toList()
        .reversed
        .toList();
  }

  /// Deletes all chat history for this student.
  Future<void> clearHistory() async {
    final snap = await _db
        .collection('chatHistory')
        .doc(userId)
        .collection('messages')
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Firestore persistence
  // ---------------------------------------------------------------------------

  Future<void> _saveMessage(ChatMessage msg) async {
    await _db
        .collection('chatHistory')
        .doc(userId)
        .collection('messages')
        .add(msg.toFirestore());
  }

  // ---------------------------------------------------------------------------
  // System prompt builder
  // ---------------------------------------------------------------------------

  String _buildSystemPrompt(
    List<CourseFitResult> rankedCourses,
    StudentInterest? studentInterest,
    StudentResultRecord? studentRecord,
  ) {
    final buf = StringBuffer();

    // ── Role definition ──────────────────────────────────────────────────────
    buf.writeln(
      'You are an academic counselling assistant for TAR UMT '
      '(Tunku Abdul Rahman University of Management and Technology) in Malaysia. '
      'Your role is to help students understand their course recommendations, '
      'explore career paths, and make informed decisions about their education.',
    );
    buf.writeln();

    // ── RIASEC profile ───────────────────────────────────────────────────────
    if (studentInterest != null && studentInterest.isComplete) {
      buf.writeln('## Student RIASEC Interest Profile');
      buf.writeln(
        'The student\'s Holland Code (RIASEC) summary is: '
        '${studentInterest.riasecCodes.join('-')}',
      );
      buf.writeln('Breakdown:');
      for (var i = 0; i < studentInterest.riasecCodes.length; i++) {
        final code = studentInterest.riasecCodes[i];
        final label = _riasecLabels[code] ?? code;
        final rank = i == 0
            ? 'Primary'
            : i == 1
                ? 'Secondary'
                : 'Tertiary';
        buf.writeln('- $rank interest: $label');
      }
      buf.writeln();
    } else {
      buf.writeln('## Student RIASEC Interest Profile');
      buf.writeln('The student has not yet completed their RIASEC assessment.');
      buf.writeln();
    }

    // ── Academic strengths ───────────────────────────────────────────────────
    if (studentRecord != null) {
      buf.writeln('## Student Academic Results (SPM)');
      final entries =
          studentRecord.toEngineInput()['SPM'] ?? <AcademicResultEntry>[];
      if (entries.isNotEmpty) {
        for (final e in entries) {
          buf.writeln('- ${e.subject}: ${e.grade}');
        }
      } else {
        buf.writeln('No SPM results on record.');
      }
      buf.writeln();
    }

    // ── Top recommended courses ──────────────────────────────────────────────
    if (rankedCourses.isNotEmpty) {
      buf.writeln('## Top Recommended Courses (ranked by overall match)');
      final top = rankedCourses.take(5).toList();
      for (var i = 0; i < top.length; i++) {
        final fit = top[i];
        final course = fit.course;
        buf.writeln('### ${i + 1}. ${course.name} (${course.code})');
        buf.writeln('- Faculty: ${course.faculty}');
        buf.writeln('- Level: ${course.level}');
        buf.writeln('- Overall Match: ${fit.overallMatchPercent}%');
        buf.writeln('- Interest Match: ${fit.interestMatchPercent}%');
        buf.writeln('- Academic Fit: ${fit.academicStrengthPercent}%');
        if (course.interestTags.isNotEmpty) {
          buf.writeln(
              '- Interest Areas: ${course.interestTags.join(', ')}');
        }

        // Admission requirements summary
        if (course.admissionPathways.isNotEmpty) {
          buf.writeln('- Admission Pathways:');
          for (final pathway in course.admissionPathways) {
            final name =
                pathway['pathwayName'] as String? ?? 'Default Pathway';
            final routes = (pathway['qualificationRoutes'] as Map?)?.keys
                    .join(', ') ??
                '';
            buf.writeln('  * $name — accepted qualifications: $routes');
          }
        }
        buf.writeln();
      }
    } else {
      buf.writeln(
          '## Recommended Courses\nNo recommendations available at this time.');
      buf.writeln();
    }

    // ── Behavioural guidelines ───────────────────────────────────────────────
    buf.writeln('## Your Guidelines');
    buf.writeln(
      '- Always be encouraging, empathetic, and professional.',
    );
    buf.writeln(
      '- When a student asks why a course is recommended, reference their '
      'specific RIASEC codes and academic grades.',
    );
    buf.writeln(
      '- When suggesting career paths, focus on the Malaysian job market '
      'and relevant industries.',
    );
    buf.writeln(
      '- When discussing strengths and weaknesses, be constructive and '
      'frame weaknesses as areas for growth.',
    );
    buf.writeln(
      '- When suggesting alternative courses, only suggest from the '
      'recommended list above unless the student asks for others.',
    );
    buf.writeln(
      '- Keep answers concise but complete. Use bullet points for lists.',
    );
    buf.writeln(
      '- Refer to Malaysian qualification terms: SPM, STPM, Diploma, '
      'Foundation, Bachelor, A-Level, UEC.',
    );
    buf.writeln(
      '- If asked something outside your scope (e.g. unrelated personal '
      'topics), politely redirect to academic counselling.',
    );
    buf.writeln();
    buf.writeln(
      'You are ready to help the student. Answer their questions based on '
      'the profile information above.',
    );

    return buf.toString();
  }
}
