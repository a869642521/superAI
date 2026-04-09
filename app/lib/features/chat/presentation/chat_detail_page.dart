import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:starpath/core/constants.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatDetailPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];

  io.Socket? _socket;
  bool _isThinking = false;
  bool _isConnected = false;
  ConversationModel? _conversation;
  String _streamingContent = '';
  String _thinkingContent = '';
  bool _showThinking = false;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages =
          await repo.getMessages(widget.conversationId);
      final convs = await ref.read(conversationsProvider.future);
      final conv = convs.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => throw Exception('conversation not found'),
      );

      if (mounted) {
        setState(() {
          _conversation = conv;
          _messages.addAll(messages.reversed);
        });
        _scrollToBottom();
        _connectSocket();
      }
    } catch (e) {
      if (mounted) _connectSocket();
    }
  }

  void _connectSocket() {
    final authState = ref.read(authProvider);
    final token = authState.token ?? '';
    final userId = authState.userId ?? '';

    _socket = io.io(
      '${AppConstants.wsBaseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setQuery({'userId': userId})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      if (mounted) setState(() => _isConnected = true);
    });

    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _isConnected = false);
    });

    _socket!.on('thinkingChunk', (data) {
      final token = (data as Map<dynamic, dynamic>)['token'] as String? ?? '';
      if (token.isNotEmpty && mounted) {
        setState(() => _thinkingContent += token);
      }
    });

    _socket!.on('messageChunk', (data) {
      final token = (data as Map<dynamic, dynamic>)['token'] as String? ?? '';
      if (token.isNotEmpty && mounted) {
        setState(() {
          _streamingContent += token;
          if (_messages.isNotEmpty &&
              _messages.last.role == 'assistant' &&
              _messages.last.id == null) {
            _messages[_messages.length - 1] = MessageModel(
              role: 'assistant',
              content: _streamingContent,
              createdAt: _messages.last.createdAt,
            );
          } else {
            _messages.add(MessageModel(
              role: 'assistant',
              content: _streamingContent,
              createdAt: DateTime.now(),
            ));
          }
        });
        _scrollToBottom();
      }
    });

    _socket!.on('messageComplete', (_) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _streamingContent = '';
          _thinkingContent = '';
        });
        HapticFeedback.lightImpact();
        ref.invalidate(conversationsProvider);
      }
    });

    _socket!.on('error', (data) {
      final msg = (data as Map<dynamic, dynamic>)['message'] as String? ??
          'AI 服务暂时不可用';
      if (mounted) {
        setState(() => _isThinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: StarpathColors.error,
          ),
        );
      }
    });

    _socket!.connect();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isThinking) return;

    final authState = ref.read(authProvider);
    final userId = authState.userId ?? '';

    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(MessageModel(
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _isThinking = true;
      _streamingContent = '';
    });
    _messageController.clear();
    _scrollToBottom();

    _socket?.emit('sendMessage', {
      'conversationId': widget.conversationId,
      'content': text,
      'userId': userId,
    });
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

  @override
  Widget build(BuildContext context) {
    final agent = _conversation?.agent;
    final gradStart = agent != null
        ? _hexToColor(agent.gradientStart)
        : StarpathColors.brandPurple;
    final gradEnd = agent != null
        ? _hexToColor(agent.gradientEnd)
        : StarpathColors.brandBlue;

    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuraAvatar(
              fallbackEmoji: agent?.emoji ?? '🤖',
              size: 32,
              gradientColors: [gradStart, gradEnd],
              state: _isThinking
                  ? CompanionState.thinking
                  : CompanionState.active,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent?.name ?? 'AI 伙伴',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected
                            ? StarpathColors.success
                            : StarpathColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isThinking
                          ? '思考中...'
                          : _isConnected
                              ? '在线'
                              : '连接中...',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isThinking
                            ? StarpathColors.warning
                            : _isConnected
                                ? StarpathColors.success
                                : StarpathColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isThinking
                ? _buildWelcome(agent?.emoji ?? '🤖', [gradStart, gradEnd])
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isThinking && _streamingContent.isEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildThinkingBubble(agent?.emoji ?? '🤖', [gradStart, gradEnd]);
                      }
                      return _buildMessageBubble(
                        _messages[index],
                        agent?.emoji ?? '🤖',
                        [gradStart, gradEnd],
                      );
                    },
                  ),
          ),
          _buildInputBar(gradStart, gradEnd),
        ],
      ),
    );
  }

  Widget _buildWelcome(String emoji, List<Color> colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: emoji,
            size: 80,
            gradientColors: colors,
            state: CompanionState.excited,
          ),
          const SizedBox(height: 20),
          Text('开始聊天吧', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '你的AI伙伴已准备就绪',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      MessageModel msg, String emoji, List<Color> gradColors) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            AuraAvatar(
              fallbackEmoji: emoji,
              size: 32,
              gradientColors: gradColors,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser ? StarpathColors.brandGradient : null,
                color: isUser ? null : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                border: isUser
                    ? null
                    : Border(
                        left: BorderSide(
                          width: 2,
                          color: gradColors[0].withValues(alpha: 0.5),
                        ),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? gradColors[0] : Colors.black)
                        .withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isUser ? Colors.white : StarpathColors.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(String emoji, List<Color> gradColors) {
    final hasThinkingText = _thinkingContent.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraAvatar(
            fallbackEmoji: emoji,
            size: 32,
            gradientColors: gradColors,
            state: CompanionState.thinking,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thinking indicator / expandable header
                GestureDetector(
                  onTap: hasThinkingText
                      ? () => setState(() => _showThinking = !_showThinking)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(3, (i) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 500 + i * 200),
                            builder: (context, value, _) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: gradColors[0]
                                      .withValues(alpha: 0.3 + 0.7 * value),
                                ),
                              );
                            },
                          );
                        }),
                        if (hasThinkingText) ...[
                          const SizedBox(width: 8),
                          Text(
                            '思考中',
                            style: TextStyle(
                              fontSize: 12,
                              color: StarpathColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showThinking
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 14,
                            color: StarpathColors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Expandable thinking content
                if (hasThinkingText && _showThinking)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: gradColors[0].withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: gradColors[0].withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      _thinkingContent,
                      style: TextStyle(
                        fontSize: 12,
                        color: StarpathColors.textSecondary,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color gradStart, Color gradEnd) {
    final canSend = !_isThinking && _messageController.text.trim().isNotEmpty;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            border: Border(
              top: BorderSide(color: StarpathColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    filled: true,
                    fillColor: StarpathColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canSend ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: canSend
                        ? LinearGradient(colors: [gradStart, gradEnd])
                        : null,
                    color: canSend
                        ? null
                        : StarpathColors.textTertiary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: canSend ? Colors.white : StarpathColors.textTertiary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
