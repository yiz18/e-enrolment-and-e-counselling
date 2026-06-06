import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single message in a student–chatbot conversation.
///
/// ### Firestore path
/// `chatHistory/{userId}/messages/{messageId}`
///
/// ### Document shape
/// ```json
/// {
///   "text":      "Why is Computer Science recommended for me?",
///   "sender":    "user",
///   "timestamp": Timestamp(2026-06-05T08:12:00Z),
///   "sessionId": "abc123"
/// }
/// ```
class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// Groups messages from one app session together so chat history can be
  /// filtered by session if needed.
  final String sessionId;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    required this.sessionId,
  });

  bool get isUser => sender == MessageSender.user;
  bool get isBot => sender == MessageSender.bot;

  // ---------------------------------------------------------------------------
  // Firestore serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toFirestore() => {
        'text': text,
        'sender': sender.name,
        'timestamp': Timestamp.fromDate(timestamp),
        'sessionId': sessionId,
      };

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      text: data['text'] as String? ?? '',
      sender: (data['sender'] as String?) == 'user'
          ? MessageSender.user
          : MessageSender.bot,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      sessionId: data['sessionId'] as String? ?? '',
    );
  }

  // ---------------------------------------------------------------------------
  // Factory helpers
  // ---------------------------------------------------------------------------

  factory ChatMessage.user({
    required String text,
    required String sessionId,
  }) =>
      ChatMessage(
        id: '',
        text: text,
        sender: MessageSender.user,
        timestamp: DateTime.now().toUtc(),
        sessionId: sessionId,
      );

  factory ChatMessage.bot({
    required String text,
    required String sessionId,
  }) =>
      ChatMessage(
        id: '',
        text: text,
        sender: MessageSender.bot,
        timestamp: DateTime.now().toUtc(),
        sessionId: sessionId,
      );
}

enum MessageSender { user, bot }
