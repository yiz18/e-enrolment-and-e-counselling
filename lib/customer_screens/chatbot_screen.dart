import 'package:flutter/material.dart';

import '../models/academic_result_entry.dart';
import '../models/chat_message.dart';
import '../models/course.dart';
import '../models/course_fit_result.dart';
import '../models/student_interest.dart';
import '../services/chatbot_service.dart';
import '../services/course_fit_matcher.dart';
import '../services/course_service.dart';
import '../services/interest_matcher.dart';
import '../services/recommendation_engine.dart';
import '../services/student_interest_service.dart';
import '../services/student_result_service.dart';
import '../services/student_session.dart';

// =============================================================================
// ChatbotScreen
// =============================================================================

/// AI-powered academic counselling chatbot screen.
///
/// On first load the screen:
/// 1. Fetches the student's RIASEC profile, academic results, and
///    recommended courses from Firestore — the same pipeline used by
///    [RecommendationScreen], invoked read-only.
/// 2. Initialises [ChatbotService] with the student context so Gemini
///    can give personalised answers.
/// 3. Restores previous chat history from Firestore.
///
/// Each new exchange is saved to `chatHistory/{userId}/messages` in real time.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // ── Services ─────────────────────────────────────────────────────────────
  final _courseService = CourseService();
  final _resultService = StudentResultService();
  final _interestService = StudentInterestService();
  final _engine = const RecommendationEngine();
  final _matcher = const InterestMatcher();
  final _fitMatcher = const CourseFitMatcher();

  late final ChatbotService _chatbotService;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isInitialising = true;
  String? _initError;

  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  // Context loaded for display in info banner
  StudentInterest? _studentInterest;
  List<CourseFitResult> _rankedCourses = [];

  // ── UI helpers ────────────────────────────────────────────────────────────
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Quick-access suggestion chips shown above the input bar
  static const List<String> _suggestions = [
    'Why is my top course recommended?',
    'What career paths suit me?',
    'What are my academic strengths?',
    'What skills do I need?',
    'Show me alternative courses',
  ];

  @override
  void initState() {
    super.initState();
    _chatbotService = ChatbotService(
      userId: StudentSession.currentStudentId,
    );
    _initialise();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialisation — load student context, start Gemini session, load history
  // ---------------------------------------------------------------------------

  Future<void> _initialise() async {
    final uid = StudentSession.currentStudentId;

    try {
      // Load in parallel: courses + RIASEC interest + academic results
      final coursesFuture = _courseService.getActiveCourses();
      final interestFuture = (uid.isNotEmpty && uid != 'guest_user')
          ? _interestService.getInterests(uid)
          : Future<StudentInterest?>.value(null);
      final recordFuture = (uid.isNotEmpty && uid != 'guest_user')
          ? _resultService.getResults(uid)
          : Future<StudentResultRecord?>.value(null);

      final List<Course> courses = await coursesFuture;
      final StudentInterest? studentInterest = await interestFuture;
      final StudentResultRecord? studentRecord = await recordFuture;

      // Build same recommendation pipeline as RecommendationScreen (read-only)
      Map<String, List<AcademicResultEntry>>? engineInput;
      if (studentRecord != null) engineInput = studentRecord.toEngineInput();

      List<CourseFitResult> rankedCourses = [];

      if (engineInput != null) {
        final spmEntries =
            engineInput['SPM'] ?? const <AcademicResultEntry>[];

        final eligible = courses
            .map((c) => _engine.evaluateCourse(c, engineInput!))
            .where((r) => r.eligible)
            .toList();

        final withInterest = eligible
            .map((r) => _matcher.wrap(r, studentInterest))
            .toList();

        rankedCourses = withInterest
            .map((r) => _fitMatcher.compute(r, spmEntries))
            .toList()
          ..sort((a, b) {
            final overall =
                b.overallMatchPercent.compareTo(a.overallMatchPercent);
            if (overall != 0) return overall;
            return b.academicStrengthScore
                .compareTo(a.academicStrengthScore);
          });
      }

      // Initialise Gemini with student context
      await _chatbotService.initialise(
        rankedCourses: rankedCourses,
        studentInterest: studentInterest,
        studentRecord: studentRecord,
      );

      // Load previous chat history
      final history = await _chatbotService.loadHistory();

      if (!mounted) return;

      setState(() {
        _studentInterest = studentInterest;
        _rankedCourses = rankedCourses;
        _messages.addAll(history);
        _isInitialising = false;
      });

      // If no history, show a welcome message
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
        _isInitialising = false;
      });
    }
  }

  void _addWelcomeMessage() {
    final riasecSummary = (_studentInterest != null &&
            _studentInterest!.isComplete)
        ? 'Your RIASEC profile is **${_studentInterest!.riasecCodes.join('-')}**. '
        : '';

    final courseHint = _rankedCourses.isNotEmpty
        ? 'Your top recommended course is **${_rankedCourses.first.course.name}**. '
        : '';

    final welcome = 'Hello! I\'m your AI academic counsellor. 👋\n\n'
        '$riasecSummary$courseHint\n\n'
        'I can help you understand:\n'
        '• Why courses are recommended for you\n'
        '• Suitable career paths\n'
        '• Required skills and knowledge\n'
        '• Your academic strengths and areas for growth\n'
        '• Alternative course options\n\n'
        'What would you like to know?';

    setState(() {
      _messages.add(ChatMessage.bot(
        text: welcome,
        sessionId: '',
      ));
    });
  }

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _controller.clear();

    setState(() {
      _messages.add(ChatMessage.user(text: trimmed, sessionId: ''));
      _isSending = true;
    });

    _scrollToBottom();

    try {
      final reply = await _chatbotService.sendMessage(trimmed);

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.bot(text: reply, sessionId: ''));
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.bot(
          text: 'Sorry, I encountered an error. Please try again.\n\n'
              'Error: ${e.toString()}',
          sessionId: '',
        ));
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Clear history
  // ---------------------------------------------------------------------------

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'This will permanently delete all your chat messages. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _chatbotService.clearHistory();
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(),
      body: _isInitialising
          ? _buildLoadingState()
          : _initError != null
              ? _buildErrorState()
              : _buildChatBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Counsellor',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (_studentInterest != null && _studentInterest!.isComplete)
            Text(
              'RIASEC: ${_studentInterest!.riasecCodes.join('-')}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
        ],
      ),
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (!_isInitialising)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'clear') _clearHistory();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Clear History'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 16),
          Text(
            'Preparing your personalised counsellor…',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Could not start the AI Counsellor',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _initError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isInitialising = true;
                  _initError = null;
                });
                _initialise();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        _ContextBanner(
          studentInterest: _studentInterest,
          topCourseCount: _rankedCourses.length,
          topCourseName: _rankedCourses.isNotEmpty
              ? _rankedCourses.first.course.name
              : null,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isSending && index == _messages.length) {
                return const _TypingIndicator();
              }
              return _MessageBubble(message: _messages[index]);
            },
          ),
        ),
        _SuggestionChips(
          suggestions: _suggestions,
          onTap: _sendMessage,
          enabled: !_isSending,
        ),
        _InputBar(
          controller: _controller,
          isSending: _isSending,
          onSend: () => _sendMessage(_controller.text),
        ),
      ],
    );
  }
}

// =============================================================================
// Context banner
// =============================================================================

class _ContextBanner extends StatelessWidget {
  final StudentInterest? studentInterest;
  final int topCourseCount;
  final String? topCourseName;

  const _ContextBanner({
    required this.studentInterest,
    required this.topCourseCount,
    required this.topCourseName,
  });

  @override
  Widget build(BuildContext context) {
    if (studentInterest == null && topCourseCount == 0) {
      return const SizedBox.shrink();
    }

    final parts = <String>[];
    if (studentInterest != null && studentInterest!.isComplete) {
      parts.add('RIASEC: ${studentInterest!.riasecCodes.join('-')}');
    }
    if (topCourseCount > 0) {
      parts.add('$topCourseCount eligible courses');
    }
    if (topCourseName != null) {
      parts.add('Top pick: $topCourseName');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.blueAccent.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              size: 14, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _BotAvatar(),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blueAccent
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isUser ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.person, size: 16, color: Colors.blueAccent),
    );
  }
}

// =============================================================================
// Typing indicator
// =============================================================================

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _BotAvatar(),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final value = ((_controller.value - delay) % 1.0)
                        .clamp(0.0, 1.0);
                    final opacity = value < 0.5
                        ? value * 2
                        : (1 - value) * 2;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: 0.3 + opacity * 0.7,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Suggestion chips
// =============================================================================

class _SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  final bool enabled;

  const _SuggestionChips({
    required this.suggestions,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: enabled ? () => onTap(suggestions[index]) : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.blueAccent.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: enabled
                      ? Colors.blueAccent.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Text(
                suggestions[index],
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.blueAccent : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Input bar
// =============================================================================

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ask about your course recommendations…',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F4FF),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                        color: Colors.blueAccent, width: 1.5),
                  ),
                ),
                onSubmitted: isSending ? null : (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSending
                    ? Colors.grey.shade300
                    : Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                color: Colors.white,
                iconSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
