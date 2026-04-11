import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  // 已稳定渲染的消息数量（用于区分"新消息"与历史消息）
  int _settledCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _messageController.addListener(() => setState(() {}));
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
      final messages = await repo.getMessages(widget.conversationId);
      final convs = await ref.read(conversationsProvider.future);
      final conv = convs.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => throw Exception('conversation not found'),
      );

      if (mounted) {
        setState(() {
          _conversation = conv;
          _messages.addAll(messages.reversed);
          _settledCount = _messages.length; // 历史消息不播入场动画
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
          _settledCount = _messages.length;
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
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    // 在线状态涟漪点
                    _OnlineDot(isConnected: _isConnected),
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
                    itemCount: _messages.length +
                        (_isThinking && _streamingContent.isEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildThinkingBubble(
                            agent?.emoji ?? '🤖', [gradStart, gradEnd]);
                      }
                      final bubble = _buildMessageBubble(
                        _messages[index],
                        agent?.emoji ?? '🤖',
                        [gradStart, gradEnd],
                        isStreaming: index == _messages.length - 1 &&
                            _streamingContent.isNotEmpty,
                      );
                      // 只对新消息播入场动画
                      if (index >= _settledCount) {
                        final isUser = _messages[index].isUser;
                        return bubble
                            .animate()
                            .fadeIn(duration: 260.ms)
                            .slideX(
                              begin: isUser ? 0.08 : -0.08,
                              duration: 260.ms,
                              curve: Curves.easeOut,
                            );
                      }
                      return bubble;
                    },
                  ),
          ),
          _buildInputBar(gradStart, gradEnd),
        ],
      ),
    );
  }

  // ── 欢迎页：弹性入场 ──────────────────────────────────────────────────────

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
          )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1.0, 1.0),
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 20),
          Text('开始聊天吧', style: Theme.of(context).textTheme.headlineSmall)
              .animate(delay: 200.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            '你的AI伙伴已准备就绪',
            style: Theme.of(context).textTheme.bodyMedium,
          )
              .animate(delay: 320.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),
        ],
      ),
    );
  }

  // ── 消息气泡：hover显示时间 ───────────────────────────────────────────────

  Widget _buildMessageBubble(
    MessageModel msg,
    String emoji,
    List<Color> gradColors, {
    bool isStreaming = false,
  }) {
    final isUser = msg.isUser;

    return _BubbleWithTimestamp(
      isUser: isUser,
      timestamp: msg.createdAt,
      child: Padding(
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser ? StarpathColors.brandGradient : null,
                  color:
                      isUser ? null : Colors.white.withValues(alpha: 0.9),
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
                child: isStreaming
                    ? _StreamingText(
                        content: msg.content,
                        textColor: isUser
                            ? Colors.white
                            : StarpathColors.textPrimary,
                      )
                    : Text(
                        msg.content,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : StarpathColors.textPrimary,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ── 思考气泡：真实循环波浪点 ──────────────────────────────────────────────

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
                GestureDetector(
                  onTap: hasThinkingText
                      ? () =>
                          setState(() => _showThinking = !_showThinking)
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
                        _BouncingDots(colors: gradColors),
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

  // ── 输入栏：发送按钮弹压+check反馈 + 聚焦边框 ────────────────────────────

  Widget _buildInputBar(Color gradStart, Color gradEnd) {
    final canSend =
        !_isThinking && _messageController.text.trim().isNotEmpty;

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
            color: Colors.white.withValues(alpha: 0.07),
            border: Border(
              top: BorderSide(
                  color: StarpathColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _FocusInputField(
                  controller: _messageController,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                canSend: canSend,
                gradStart: gradStart,
                gradEnd: gradEnd,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 在线状态涟漪点 ────────────────────────────────────────────────────────────

class _OnlineDot extends StatefulWidget {
  final bool isConnected;
  const _OnlineDot({required this.isConnected});

  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ripple;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ripple = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.isConnected) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_OnlineDot old) {
    super.didUpdateWidget(old);
    if (widget.isConnected && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isConnected && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isConnected
        ? StarpathColors.success
        : StarpathColors.textTertiary;

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isConnected)
            AnimatedBuilder(
              animation: _ripple,
              builder: (_, __) {
                final r = _ripple.value;
                return Container(
                  width: 6 + r * 8,
                  height: 6 + r * 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: (1 - r) * 0.45),
                  ),
                );
              },
            ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}

// ── 真实循环弹跳波浪点 ────────────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  final List<Color> colors;
  const _BouncingDots({required this.colors});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final begin = i * 0.28;
        final end = (begin + 0.50).clamp(0.0, 1.0);
        final anim = Tween<double>(begin: 0, end: -7).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Interval(begin, end, curve: Curves.easeInOut),
          ),
        );
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, anim.value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.colors[0].withValues(alpha: 0.75),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── 气泡 hover 显示时间戳 ─────────────────────────────────────────────────────

class _BubbleWithTimestamp extends StatefulWidget {
  final Widget child;
  final bool isUser;
  final DateTime? timestamp;

  const _BubbleWithTimestamp({
    required this.child,
    required this.isUser,
    this.timestamp,
  });

  @override
  State<_BubbleWithTimestamp> createState() => _BubbleWithTimestampState();
}

class _BubbleWithTimestampState extends State<_BubbleWithTimestamp> {
  bool _hovered = false;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.timestamp;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          widget.child,
          if (ts != null)
            Positioned.fill(
              child: Align(
                alignment: widget.isUser
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.isUser ? 12 : 0,
                    right: widget.isUser ? 0 : 12,
                    bottom: 12,
                  ),
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _formatTime(ts),
                      style: TextStyle(
                        fontSize: 10,
                        color: StarpathColors.textTertiary
                            .withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 流式消息末尾闪烁光标 ──────────────────────────────────────────────────────

class _StreamingText extends StatefulWidget {
  final String content;
  final Color textColor;

  const _StreamingText(
      {required this.content, required this.textColor});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _blink = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (_, __) {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: widget.content,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Opacity(
                  opacity: _blink.value,
                  child: Container(
                    width: 2,
                    height: 16,
                    margin: const EdgeInsets.only(left: 1),
                    decoration: BoxDecoration(
                      color: widget.textColor.withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 聚焦边框输入框 ────────────────────────────────────────────────────────────

class _FocusInputField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _FocusInputField(
      {required this.controller, required this.onSubmitted});

  @override
  State<_FocusInputField> createState() => _FocusInputFieldState();
}

class _FocusInputFieldState extends State<_FocusInputField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: StarpathColors.accentViolet.withValues(alpha: 0.28),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: '输入消息...',
          filled: true,
          fillColor: StarpathColors.surfaceContainerHigh,
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
            borderSide: BorderSide(
              color: StarpathColors.accentViolet.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        maxLines: 4,
        minLines: 1,
        textInputAction: TextInputAction.send,
        onChanged: (_) {},
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

// ── 发送按钮：弹压 + check 反馈 + hover ──────────────────────────────────────

class _SendButton extends StatefulWidget {
  final bool canSend;
  final Color gradStart;
  final Color gradEnd;
  final VoidCallback onSend;

  const _SendButton({
    required this.canSend,
    required this.gradStart,
    required this.gradEnd,
    required this.onSend,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _showCheck = false;

  void _handleTap() {
    if (!widget.canSend) return;
    HapticFeedback.mediumImpact();
    widget.onSend();
    setState(() => _showCheck = true);
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _showCheck = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.canSend
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _handleTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : (_hovered && widget.canSend ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: widget.canSend
                  ? LinearGradient(
                      colors: [widget.gradStart, widget.gradEnd],
                    )
                  : null,
              color: widget.canSend
                  ? null
                  : StarpathColors.textTertiary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              boxShadow: widget.canSend && _hovered
                  ? [
                      BoxShadow(
                        color: widget.gradStart.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _showCheck
                    ? Icons.check_rounded
                    : Icons.send_rounded,
                key: ValueKey(_showCheck),
                color: widget.canSend
                    ? Colors.white
                    : StarpathColors.textTertiary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
