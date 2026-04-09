import 'package:equatable/equatable.dart';

class ConversationModel extends Equatable {
  final String id;
  final String userId;
  final String agentId;
  final String title;
  final DateTime lastMessageAt;
  final AgentBrief agent;
  final MessageModel? lastMessage;

  const ConversationModel({
    required this.id,
    required this.userId,
    required this.agentId,
    required this.title,
    required this.lastMessageAt,
    required this.agent,
    this.lastMessage,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'] as List<dynamic>?;
    MessageModel? lastMsg;
    if (messages != null && messages.isNotEmpty) {
      lastMsg = MessageModel.fromJson(messages.first as Map<String, dynamic>);
    }

    return ConversationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      agentId: json['agentId'] as String,
      title: json['title'] as String? ?? '',
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      agent: AgentBrief.fromJson(json['agent'] as Map<String, dynamic>),
      lastMessage: lastMsg,
    );
  }

  @override
  List<Object?> get props => [id];
}

class AgentBrief {
  final String id;
  final String name;
  final String emoji;
  final String gradientStart;
  final String gradientEnd;

  const AgentBrief({
    required this.id,
    required this.name,
    required this.emoji,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory AgentBrief.fromJson(Map<String, dynamic> json) {
    return AgentBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🤖',
      gradientStart: json['gradientStart'] as String? ?? '#6C63FF',
      gradientEnd: json['gradientEnd'] as String? ?? '#00D2FF',
    );
  }
}

class MessageModel extends Equatable {
  final String? id;
  final String role;
  final String content;
  final DateTime createdAt;

  const MessageModel({
    this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  @override
  List<Object?> get props => [id, content];
}
