import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/constants.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/data/main_partner_provider.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';
import 'package:starpath/features/voice_dialog/voice_dialog_bridge.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

/// ip 封面图列表（同 agent_studio_page.dart 保持一致）
const List<String> _kIpAvatars = [
  'images/ip0.png',
  'images/ip1.png',
  'images/ip2.png',
  'images/ip3.png',
  'images/ip4.png',
  'images/ip5.png',
  'images/ip7.png',
];

/// 沉浸页角色视频相对「铺满视口」的缩放（<1 略缩小，四周留黑边）
const double _kChatHeroVideoScaleFactor = 0.78;

/// AI 伙伴对话页全屏底色
const Color _kChatPageBackground = Color(0xFF18082A);

/// 伙伴回复气泡底色（不透明）
const Color _kPartnerReplyBubbleColor = Color(0xFF341545);

/// 颜色矩阵：将像素亮度映射到 alpha 通道，黑色→透明、亮色→不透明。
/// 通过 ColorFilterLayer 在合成器层面生效，能作用于 VideoPlayer 的 TextureLayer。
/// A' = 0.30R + 0.59G + 0.11B − 0.10（负偏移让近黑区也透明，过渡更干净）
const ColorFilter _kBlackRemovalFilter = ColorFilter.matrix(<double>[
  //  R      G      B      A    offset
      1,     0,     0,     0,   0,      // R' = R
      0,     1,     0,     0,   0,      // G' = G
      0,     0,     1,     0,   0,      // B' = B
      0.30,  0.59,  0.11,  0,  -0.10,  // A' = luma − 0.10
]);

/// 与页面蓝紫底呼应的渐变，经 [ShaderMask] + [BlendMode.screen] 与视频逐像素滤色混合。
/// 说明：canvas.saveLayer 无法可靠作用在 VideoPlayer 的 Texture 上；ShaderMask 走另一套合成路径。
Shader _chatHeroScreenBlendShader(Rect bounds) {
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4D96FF),
      Color(0xFF6366F1),
      Color(0xFF9B72FF),
    ],
    stops: [0.0, 0.48, 1.0],
  ).createShader(bounds);
}

/// 对话页四段视频阶段（与 Spotlight 卡片保持一致）
enum _ChatVideoPhase { hello, hait, breathe, down }

/// 文字输入栏上方快捷推荐语（emoji + 文案）
const List<(String emoji, String text)> _kChatQuickSuggests = [
  ('👋', '你好 请问今天你做了什么呀'),
  ('🙋', '请介绍一下你自己'),
  ('📖', '给我讲个故事'),
];

/// 根据 agentId 取对应 ip 头像路径。
/// 规则：提取 agentId 末尾数字，若无则取哈希，循环匹配列表。
String _ipAvatarForAgent(String? agentId) {
  if (agentId == null || agentId.isEmpty) return _kIpAvatars[0];
  final digits = RegExp(r'\d+').allMatches(agentId);
  if (digits.isNotEmpty) {
    final n = int.parse(digits.last.group(0)!);
    return _kIpAvatars[n % _kIpAvatars.length];
  }
  return _kIpAvatars[agentId.hashCode.abs() % _kIpAvatars.length];
}

/// 圆形 ip 头像 Widget
Widget _ipAvatarWidget({required String? agentId, required double size}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 2),
    child: Image.asset(
      _ipAvatarForAgent(agentId),
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    ),
  );
}

class ChatDetailPage extends ConsumerStatefulWidget {
  /// 直接传会话 ID（优先使用）
  final String? conversationId;

  /// 仅传 agentId 时，页面内部自动 findOrCreate 会话
  final String? agentId;

  /// 从 Spotlight 卡片进入时传入的角色专属视频
  final String? helloVideo;
  final String? haitVideo;
  final String? breatheVideo;
  final String? downVideo;

  /// 从 Spotlight 卡片传入的显示名称（后端未响应前优先展示）
  final String? agentName;

  const ChatDetailPage({
    super.key,
    this.conversationId,
    this.agentId,
    this.helloVideo,
    this.haitVideo,
    this.breatheVideo,
    this.downVideo,
    this.agentName,
  }) : assert(
          conversationId != null || agentId != null,
          'conversationId or agentId is required',
        );

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

/// 连接状态展示：WS 已连 / 仅有本地会话（无 WS）/ 仍在初始化
enum _ChatConnUi { connecting, demo, live }

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _chatInputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];

  io.Socket? _socket;
  bool _isThinking = false;
  bool _isConnected = false;
  ConversationModel? _conversation;
  String _streamingContent = '';
  String _thinkingContent = '';
  bool _showThinking = false;
  bool _showTextInput = false;
  /// true = 语音沉浸模式（三按钮栏 + 沉浸视图）；false = 聊天文字模式
  /// 进入时默认语音模式；点键盘切到聊天模式；点麦克风切回语音模式。
  bool _voiceBarWithMessages = true;

  // 防止无后端时 _isThinking 永不清除：发消息后 60s 若无响应则自动复位
  static const _kThinkingTimeout = Duration(seconds: 60);
  Timer? _thinkingTimer;

  // 已稳定渲染的消息数量（用于区分"新消息"与历史消息）
  int _settledCount = 0;

  // ── 视频背景：hello(×1)→hait(×1)→breathe(∞)；点击→down(×1)→hait(×1)→breathe(∞) ──
  VideoPlayerController? _helloCtrl;
  VideoPlayerController? _haitCtrl;
  VideoPlayerController? _breatheCtrl;
  VideoPlayerController? _downCtrl;
  bool _videoReady = false;
  /// 当前播放阶段（同 Spotlight 卡片）
  _ChatVideoPhase _videoPhase = _ChatVideoPhase.hello;

  // ── 语音识别（默认连续聆听，无弹窗）──────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  /// 沉浸页实时识别文案（有消息时也可在后台识别并自动发送）
  String _voiceTranscript = '';

  // ── TTS：语音发话后，在回复完成时朗读助手文本 ───────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _pendingSpeakAssistantReply = false;
  bool _ttsPlaying = false;

  // ── 火山引擎实时语音对话桥接（接入 SDK 后替代 STT + TTS 方案）──────────────
  final VoiceDialogBridge _voiceBridge = VoiceDialogBridge();
  StreamSubscription<VoiceDialogEvent>? _voiceBridgeSub;
  /// 当前 AI 正在通过 SDK 说话（用于 UI 指示 / 打断按钮）
  bool _sdkAiSpeaking = false;
  /// 已通过 SDK 收到的 AI 回复文本（流式拼接）
  String _sdkAiBuffer = '';

  /// 是否走火山实时语音 SDK：构建/运行时传入
  /// `flutter run --dart-define=VOLC_VOICE_SDK=true --dart-define=VOLC_APP_ID=... --dart-define=VOLC_APP_TOKEN=...`
  /// 勿把密钥写入仓库；密钥泄露请到控制台轮换。
  static const bool _useVolcSdk =
      bool.fromEnvironment('VOLC_VOICE_SDK', defaultValue: false);
  static const String _volcAppId =
      String.fromEnvironment('VOLC_APP_ID', defaultValue: '');
  static const String _volcAppToken =
      String.fromEnvironment('VOLC_APP_TOKEN', defaultValue: '');

  /// 无历史消息且未切键盘：展示底部语音沉浸栏；有历史消息：始终可语音。
  /// WebSocket 未连上但 REST 已拿到会话时，不再显示「连接中」。
  _ChatConnUi get _connUi {
    if (_isConnected) return _ChatConnUi.live;
    if (_conversation != null) return _ChatConnUi.demo;
    return _ChatConnUi.connecting;
  }

  bool get _shouldRunContinuousVoice =>
      _sttAvailable &&
      _conversation != null &&
      !_ttsPlaying &&        // TTS 说话时暂停，避免把 AI 音频当用户输入
      !_isThinking &&        // AI 思考时暂停，减少不必要的音频冲突
      (_messages.isNotEmpty || !_showTextInput);

  @override
  void initState() {
    super.initState();
    _loadConversation();
    if (_useVolcSdk) {
      _initVolcVoice();
    } else {
      _initStt();
      _initTts();
    }
    _initBgVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _continuousVoiceWorker();
    });
  }

  // ── 视频初始化 ─────────────────────────────────────────────────────────────

  VideoPlayerController _makeCtrl(String asset) => kIsWeb
      ? VideoPlayerController.networkUrl(Uri.parse('assets/$asset'))
      : VideoPlayerController.asset(asset);

  Future<VideoPlayerController?> _initOne(String? asset,
      {required bool loop}) async {
    if (asset == null) return null;
    final c = _makeCtrl(asset);
    try {
      await c.initialize();
      if (!mounted) { await c.dispose(); return null; }
      await c.setLooping(loop);
      await c.setVolume(0);
      return c;
    } catch (e) {
      debugPrint('[BgVideo] $asset: $e');
      await c.dispose();
      return null;
    }
  }

  Future<void> _initBgVideo() async {
    // 优先用 Spotlight 卡片传入的素材，否则回退到默认两段视频
    final helloAsset   = widget.helloVideo   ?? 'video/jq.mp4';
    final haitAsset    = widget.haitVideo    ?? 'video/jq2.mp4';
    final breatheAsset = widget.breatheVideo;   // 无默认
    final downAsset    = widget.downVideo;       // 无默认

    final results = await Future.wait([
      _initOne(helloAsset,   loop: false),
      _initOne(haitAsset,    loop: false),
      _initOne(breatheAsset, loop: true),
      _initOne(downAsset,    loop: false),
    ]);
    if (!mounted) return;
    _helloCtrl   = results[0];
    _haitCtrl    = results[1];
    _breatheCtrl = results[2];
    _downCtrl    = results[3];
    if (mounted) setState(() => _videoReady = true);
    _bgBeginHello();
  }

  // ── hello(×1) ──────────────────────────────────────────────────
  Future<void> _bgBeginHello() async {
    if (!mounted) return;
    final c = _helloCtrl;
    if (c != null) {
      await c.seekTo(Duration.zero);
      c.addListener(_bgOnHelloTick);
      await c.play();
      if (mounted) setState(() => _videoPhase = _ChatVideoPhase.hello);
    } else {
      _bgBeginHait();
    }
  }

  void _bgOnHelloTick() {
    final c = _helloCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnHelloTick);
      c.pause();
      _bgBeginHait();
    }
  }

  // ── hait(×1) → breathe(∞) ──────────────────────────────────────
  Future<void> _bgBeginHait() async {
    if (!mounted) return;
    final c = _haitCtrl;
    if (c != null) {
      await c.seekTo(Duration.zero);
      c.addListener(_bgOnHaitTick);
      await c.play();
      if (mounted) setState(() => _videoPhase = _ChatVideoPhase.hait);
    } else {
      _bgBeginBreathe();
    }
  }

  void _bgOnHaitTick() {
    final c = _haitCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnHaitTick);
      c.pause();
      _bgBeginBreathe();
    }
  }

  Future<void> _bgBeginBreathe() async {
    if (!mounted) return;
    final c = _breatheCtrl;
    if (c != null) {
      await c.seekTo(Duration.zero);
      await c.play();
      if (mounted) setState(() => _videoPhase = _ChatVideoPhase.breathe);
    }
  }

  // ── 用户点击热区：down(×1) → hait → breathe ────────────────────
  Future<void> _replayBgVideoFromHotZone() async {
    if (!_videoReady) return;
    final down = _downCtrl;
    if (down == null || !down.value.isInitialized) {
      // 没有 down 素材 → 重播 hello
      _bgPauseCurrent();
      _bgBeginHello();
      return;
    }
    if (_videoPhase == _ChatVideoPhase.down) return;
    HapticFeedback.lightImpact();
    _bgPauseCurrent();
    await down.seekTo(Duration.zero);
    down.addListener(_bgOnDownTick);
    await down.play();
    if (mounted) setState(() => _videoPhase = _ChatVideoPhase.down);
  }

  void _bgOnDownTick() {
    final c = _downCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnDownTick);
      c.pause();
      c.seekTo(Duration.zero);
      _bgBeginHait();
    }
  }

  void _bgPauseCurrent() {
    switch (_videoPhase) {
      case _ChatVideoPhase.hello:
        _helloCtrl?.removeListener(_bgOnHelloTick);
        _helloCtrl?.pause();
      case _ChatVideoPhase.hait:
        _haitCtrl?.removeListener(_bgOnHaitTick);
        _haitCtrl?.pause();
      case _ChatVideoPhase.breathe:
        _breatheCtrl?.pause();
      case _ChatVideoPhase.down:
        break;
    }
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize();
    if (mounted) setState(() => _sttAvailable = ok);
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      // TTS 开始播放：暂停 STT
      _tts.setStartHandler(() {
        if (mounted) setState(() => _ttsPlaying = true);
      });
      // TTS 播放完毕：恢复 STT（continuous worker 自动重启 listen）
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _ttsPlaying = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _ttsPlaying = false);
      });
      _tts.setErrorHandler((msg) {
        debugPrint('[TTS] error: $msg');
        if (mounted) setState(() => _ttsPlaying = false);
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
    }
  }

  // ── 火山引擎 SDK 实时对话 ────────────────────────────────────────────────────

  Future<void> _initVolcVoice() async {
    if (_volcAppId.isEmpty || _volcAppToken.isEmpty) {
      debugPrint(
          '[VolcVoice] 未配置 VOLC_APP_ID / VOLC_APP_TOKEN，回退 STT+TTS');
      await _initStt();
      await _initTts();
      return;
    }
    await _voiceBridge.prepareEnvironment();
    _voiceBridgeSub = _voiceBridge.events.listen(_onVolcEvent);
    final ok = await _voiceBridge.startDialog(const VoiceDialogConfig(
      appId:    _volcAppId,
      appToken: _volcAppToken,
    ));
    if (!ok && mounted) {
      debugPrint('[VolcVoice] startDialog failed, fallback to STT/TTS');
      await _initStt();
      await _initTts();
    }
  }

  void _onVolcEvent(VoiceDialogEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case VoiceDialogEventType.connected:
        debugPrint('[VolcVoice] connected');

      case VoiceDialogEventType.userSpeaking:
        // 实时显示用户正在说的内容
        setState(() => _voiceTranscript = event.text ?? '');

      case VoiceDialogEventType.userFinalText:
        // 用户一句话结束，添加消息气泡
        final text = event.text ?? '';
        if (text.isNotEmpty && !_isThinking) {
          setState(() {
            _voiceTranscript = '';
            _messages.add(MessageModel(
              role: 'user',
              content: text,
              createdAt: DateTime.now(),
            ));
            _isThinking = true;
            _sdkAiBuffer = '';
          });
          _scrollToBottom();
        }

      case VoiceDialogEventType.aiSpeaking:
        setState(() {
          _sdkAiSpeaking = true;
          _sdkAiBuffer = '';
          // 开始 AI 消息气泡
          if (_messages.isEmpty || _messages.last.isUser) {
            _messages.add(MessageModel(
              role: 'assistant',
              content: '',
              createdAt: DateTime.now(),
            ));
          }
        });
        // AI 开口时播放 down 动画
        _replayBgVideoFromHotZone();

      case VoiceDialogEventType.aiTextDelta:
        // 流式文本拼到最后一条 assistant 消息
        final delta = event.text ?? '';
        if (delta.isNotEmpty) {
          setState(() {
            _sdkAiBuffer += delta;
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              _messages[_messages.length - 1] = MessageModel(
                role: 'assistant',
                content: _sdkAiBuffer,
                createdAt: _messages.last.createdAt,
              );
            }
          });
          _scrollToBottom();
        }

      case VoiceDialogEventType.aiRoundDone:
        setState(() {
          _sdkAiSpeaking = false;
          _isThinking = false;
          _settledCount = _messages.length;
        });
        HapticFeedback.lightImpact();
        ref.invalidate(conversationsProvider);

      case VoiceDialogEventType.interrupted:
        setState(() => _sdkAiSpeaking = false);

      case VoiceDialogEventType.error:
        debugPrint('[VolcVoice] error: ${event.errorMessage}');
        setState(() {
          _isThinking = false;
          _sdkAiSpeaking = false;
        });

      case VoiceDialogEventType.disconnected:
        setState(() {
          _sdkAiSpeaking = false;
          _isThinking = false;
        });
    }
  }

  Future<void> _stopAssistantSpeech() async {
    try {
      await _tts.stop();
      if (mounted) setState(() => _ttsPlaying = false);
    } catch (_) {}
  }

  Future<void> _speakAssistantReplyIfNeeded() async {
    final should = _pendingSpeakAssistantReply;
    _pendingSpeakAssistantReply = false;
    if (!should || !_ttsReady || !mounted) return;
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.isUser) return;
    final text = last.content.trim();
    if (text.isEmpty) return;
    try {
      // 先停掉 STT，再开始 TTS，彻底避免音频冲突
      await _stt.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TTS] speak failed: $e');
      if (mounted) setState(() => _ttsPlaying = false);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords;
    setState(() => _voiceTranscript = words);
    if (result.finalResult && words.trim().isNotEmpty && !_isThinking) {
      _sendVoiceMessage(words.trim(), speakAssistantReply: true);
      if (mounted) setState(() => _voiceTranscript = '');
    }
  }

  /// 后台循环：满足条件时持续 listen，切键盘或离开时 stop。
  Future<void> _continuousVoiceWorker() async {
    while (mounted) {
      if (!_shouldRunContinuousVoice) {
        if (_stt.isListening) await _stt.stop();
        if (mounted) setState(() {});
        await Future<void>.delayed(const Duration(milliseconds: 280));
        continue;
      }

      try {
        if (mounted) setState(() {});
        await _stt.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(minutes: 3),
          pauseFor: const Duration(seconds: 3),
          localeId: 'zh_CN',
          listenOptions: SpeechListenOptions(
            cancelOnError: true,
            partialResults: true,
          ),
        );
      } catch (e, st) {
        debugPrint('[STT] listen error: $e\n$st');
      }

      if (!mounted) break;
      if (mounted) setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _sendVoiceMessage(String text, {bool speakAssistantReply = false}) {
    if (text.isEmpty || _isThinking) return;

    unawaited(_stopAssistantSpeech());
    if (speakAssistantReply) {
      _pendingSpeakAssistantReply = true;
    }

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
    _startThinkingTimeout();

    _socket?.emit('sendMessage', {
      'conversationId': _conversation?.id ?? widget.conversationId ?? '',
      'content': text,
      'userId': userId,
    });
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _bgPauseCurrent();
    _helloCtrl?.dispose();
    _haitCtrl?.dispose();
    _breatheCtrl?.dispose();
    _downCtrl?.removeListener(_bgOnDownTick);
    _downCtrl?.dispose();
    _stt.stop();
    unawaited(_stopAssistantSpeech());
    unawaited(_voiceBridgeSub?.cancel());
    unawaited(_voiceBridge.dispose());
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _chatInputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      final repo = ref.read(chatRepositoryProvider);

      // 若只有 agentId，先 findOrCreate 会话
      String convId = widget.conversationId ?? '';
      if (convId.isEmpty && widget.agentId != null) {
        final created = await repo.createConversation(widget.agentId!);
        convId = created.id;
        if (mounted) ref.invalidate(conversationsProvider);
      }

      final messages = await repo.getMessages(convId);
      final convs = await ref.read(conversationsProvider.future);
      final conv = convs.firstWhere(
        (c) => c.id == convId,
        orElse: () => throw Exception('conversation not found'),
      );

      if (mounted) {
        setState(() {
          _conversation = conv;
          _messages.addAll(messages.reversed);
          _settledCount = _messages.length;
        });
        _scrollToBottom();
        _connectSocket();
      }
    } catch (e) {
      if (mounted) {
        // 后端不可用时，设置占位会话，UI 进入演示模式而不是永久"连接中"
        setState(() {
          _conversation ??= ConversationModel(
            id: widget.conversationId ?? widget.agentId ?? 'demo',
            userId: '',
            agentId: widget.agentId ?? widget.conversationId ?? '',
            title: 'AI 伙伴',
            lastMessageAt: DateTime.now(),
            agent: const AgentBrief(
              id: '',
              name: 'AI 伙伴',
              emoji: '🤖',
              gradientStart: '#6C63FF',
              gradientEnd: '#00D2FF',
            ),
          );
        });
        _connectSocket();
      }
    }
  }

  void _connectSocket() {
    _socket?.dispose();
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

    _socket!.onConnectError((data) {
      debugPrint('[ChatSocket] connect_error: $data');
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
        unawaited(_speakAssistantReplyIfNeeded());
      }
    });

    _socket!.on('error', (data) {
      final msg = (data as Map<dynamic, dynamic>)['message'] as String? ??
          'AI 服务暂时不可用';
      if (mounted) {
        _pendingSpeakAssistantReply = false;
        unawaited(_stopAssistantSpeech());
        setState(() => _isThinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: StarpathColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _socket!.connect();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isThinking) return;
    _sendVoiceMessage(text);
  }

  void _startThinkingTimeout() {
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(_kThinkingTimeout, () {
      if (mounted && _isThinking) {
        _pendingSpeakAssistantReply = false;
        unawaited(_stopAssistantSpeech());
        setState(() {
          _isThinking = false;
          _streamingContent = '';
          _thinkingContent = '';
          // 若最后一条是空的 assistant 消息，移除它
          if (_messages.isNotEmpty &&
              !_messages.last.isUser &&
              _messages.last.content.trim().isEmpty) {
            _messages.removeLast();
          }
        });
      }
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
    // 有消息 && 不在语音模式 → 显示消息列表；其余情况显示沉浸视图
    final hasMessages =
        (_messages.isNotEmpty || _isThinking) && !_voiceBarWithMessages;
    final showTextInputBar =
        (_messages.isNotEmpty || _isThinking)
            ? !_voiceBarWithMessages
            : _showTextInput;

    return Scaffold(
      backgroundColor: _kChatPageBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
              child: ColoredBox(color: _kChatPageBackground)),
          // ── 角色视频：黑底抠 alpha + ShaderMask 滤色与渐变 shader 混合 ───
          if (_videoReady)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) {
                  final VideoPlayerController? ctrl = switch (_videoPhase) {
                    _ChatVideoPhase.hello   => _helloCtrl,
                    _ChatVideoPhase.hait    => _haitCtrl,
                    _ChatVideoPhase.breathe => _breatheCtrl,
                    _ChatVideoPhase.down    => _downCtrl,
                  };
                  if (ctrl == null || !ctrl.value.isInitialized) {
                    return const SizedBox.shrink();
                  }
                  final videoSize = ctrl.value.size;
                  if (videoSize == Size.zero) {
                    return const SizedBox.shrink();
                  }
                  final scaleW = box.maxWidth / videoSize.width;
                  final scaleH = box.maxHeight / videoSize.height;
                  final coverScale = scaleW > scaleH ? scaleW : scaleH;
                  final scale = coverScale * _kChatHeroVideoScaleFactor;
                  return ClipRect(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: videoSize.width,
                          height: videoSize.height,
                          child: ShaderMask(
                            blendMode: BlendMode.screen,
                            shaderCallback: _chatHeroScreenBlendShader,
                            child: ColorFiltered(
                              colorFilter: _kBlackRemovalFilter,
                              child: VideoPlayer(ctrl),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // ── 聊天时：全屏黑色蒙层盖住视频（不用 BackdropFilter 避免导航过渡残影）
          if (hasMessages)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Color(0xCC000000)),
              ),
            ),
          // ── 页面内容 ──────────────────────────────────────────────────
          Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top),
              _buildTopBar(agent, gradStart, gradEnd),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 全宽 × 500px 热区（不高于当前可用高度）
                    final hotH = 500.0.clamp(0.0, constraints.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // 热区在下层：全宽条带，列表/沉浸内容在上层
                        if (_videoReady)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: hotH,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _replayBgVideoFromHotZone,
                              child: const ColoredBox(color: Colors.transparent),
                            ),
                          ),
                        Positioned.fill(
                          child: hasMessages
                              ? _buildChatBody(
                                  agent, gradStart, gradEnd)
                              : _buildImmersiveView(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (showTextInputBar)
                _buildInputBar(gradStart, gradEnd)
              else
                _buildVoiceControls(gradStart, gradEnd),
            ],
          ),
        ],
      ),
    );
  }

  // ── 自定义顶栏 ────────────────────────────────────────────────────────────

  /// 与 Spotlight 长卡片 [agentName] 一致；无 query 时再显示会话里的 Agent 名。
  String _topBarAgentTitle(AgentBrief? agent) {
    final fromCard = widget.agentName?.trim();
    if (fromCard != null && fromCard.isNotEmpty) return fromCard;
    return agent?.name ?? 'AI 伙伴';
  }

  Widget _buildTopBar(AgentBrief? agent, Color gradStart, Color gradEnd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StarpathColors.surfaceContainerHigh
                    .withValues(alpha: 0.75),
                border: Border.all(
                    color: StarpathColors.outlineVariant, width: 0.8),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: StarpathColors.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          // 头像
          _ipAvatarWidget(agentId: widget.agentId, size: 36),
          const SizedBox(width: 10),
          // 名称 + 状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _topBarAgentTitle(agent),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: StarpathColors.onSurface),
                ),
                Row(
                  children: [
                    _OnlineDot(status: _connUi),
                    const SizedBox(width: 4),
                    Text(
                      _isThinking
                          ? '思考中...'
                          : switch (_connUi) {
                              _ChatConnUi.live => '在线',
                              _ChatConnUi.demo => '演示模式',
                              _ChatConnUi.connecting => '连接中...',
                            },
                      style: TextStyle(
                        fontSize: 11,
                        color: _isThinking
                            ? StarpathColors.warning
                            : switch (_connUi) {
                                _ChatConnUi.live => StarpathColors.success,
                                _ChatConnUi.demo => StarpathColors.warning,
                                _ChatConnUi.connecting =>
                                  StarpathColors.textTertiary,
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右侧操作按钮：设定主伙伴 / 更换伙伴
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showPartnerOptions(context);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StarpathColors.surfaceContainerHigh
                    .withValues(alpha: 0.75),
                border: Border.all(
                    color: StarpathColors.outlineVariant, width: 0.8),
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  size: 20, color: StarpathColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // ── 右侧菜单：设定主伙伴 / 更换伙伴 ──────────────────────────────────────

  void _showPartnerOptions(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: StarpathColors.outlineVariant.withValues(alpha: 0.5),
                width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: StarpathColors.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _PartnerOptionTile(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFD700),
                label: '设定为主伙伴',
                subtitle: '点击中间导航按钮时直接进入此伙伴',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _setAsMainPartner(ctx);
                },
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: StarpathColors.outlineVariant.withValues(alpha: 0.3),
              ),
              _PartnerOptionTile(
                icon: Icons.swap_horiz_rounded,
                iconColor: StarpathColors.primary,
                label: '更换伙伴',
                subtitle: '前往伙伴列表选择其他 AI',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ctx.go('/agents');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _setAsMainPartner(BuildContext ctx) {
    final agentId = widget.agentId;
    final agentName = widget.agentName;

    if (agentId == null || agentId.isEmpty) return;

    final partner = MainPartnerState(
      agentId:      agentId,
      agentName:    agentName ?? agentId,
      helloVideo:   widget.helloVideo,
      haitVideo:    widget.haitVideo,
      breatheVideo: widget.breatheVideo,
      downVideo:    widget.downVideo,
    );

    ref.read(mainPartnerProvider.notifier).setMainPartner(partner);

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('已将「${partner.agentName}」设定为主伙伴'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2D1B5E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── 有消息时的普通聊天区域 ─────────────────────────────────────────────────

  Widget _buildChatBody(
      AgentBrief? agent, Color gradStart, Color gradEnd) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount:
          _messages.length + (_isThinking && _streamingContent.isEmpty ? 1 : 0),
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
    );
  }

  // ── 沉浸式欢迎视图（无历史消息时） ──────────────────────────────────────

  Widget _buildImmersiveView() {
    return Stack(
      children: [
        // ── 问候文字（左上区域） ─────────────────────────────────────────
        Positioned(
          top: 16,
          left: 24,
          right: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '嗨，你好！',
                style:
                    Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: StarpathColors.onSurface,
                          height: 1.1,
                        ),
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOut),
              const SizedBox(height: 10),
              Text(
                switch (_connUi) {
                  _ChatConnUi.live =>
                    '我已经准备好陪你啦，\n有什么想聊的尽管说～',
                  _ChatConnUi.demo =>
                    '当前未连上实时服务（演示模式），\n界面可先体验；完整对话需启动后端。',
                  _ChatConnUi.connecting => '正在连接中，请稍候...',
                },
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: StarpathColors.onSurfaceVariant,
                      height: 1.6,
                    ),
              )
                  .animate(delay: 220.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOut),
            ],
          ),
        ),

        // ── 状态胶囊（右上角） ───────────────────────────────────────────
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:
                  StarpathColors.surfaceContainer.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: StarpathColors.outlineVariant, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (_connUi) {
                      _ChatConnUi.live => StarpathColors.success,
                      _ChatConnUi.demo => StarpathColors.warning,
                      _ChatConnUi.connecting =>
                        StarpathColors.textTertiary,
                    },
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  switch (_connUi) {
                    _ChatConnUi.live => '智能对话中',
                    _ChatConnUi.demo => '演示模式',
                    _ChatConnUi.connecting => '连接中...',
                  },
                  style: const TextStyle(
                    fontSize: 11,
                    color: StarpathColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.2, curve: Curves.easeOut),
        ),
      ],
    );
  }

  // ── 底部三按钮操作栏 ───────────────────────────────────────────────────────

  Widget _buildVoiceControls(Color gradStart, Color gradEnd) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final listening = _stt.isListening;
    final hint = !_sttAvailable
        ? '当前设备不支持语音识别...'
        : (listening ? '正在聆听...' : '准备就绪，请直接说话...');

    return Container(
      padding: EdgeInsets.only(bottom: bottom + 24, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Text(
              _voiceTranscript.isEmpty ? hint : _voiceTranscript,
              style: TextStyle(
                color: _voiceTranscript.isEmpty
                    ? (listening
                        ? gradStart.withValues(alpha: 0.88)
                        : StarpathColors.textTertiary)
                    : StarpathColors.onSurface,
                fontSize: 15,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _VoiceButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 20),
              // 语音模式中心按钮：
          // - SDK 模式：AI 说话时变为「打断」按钮，其余时间为麦克风
          // - 普通模式：始终为麦克风图标
              _VoiceButton(
                icon: (_useVolcSdk && _sdkAiSpeaking)
                    ? Icons.stop_circle_outlined
                    : Icons.mic_rounded,
                highlight: true,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (_useVolcSdk && _sdkAiSpeaking) {
                    unawaited(_voiceBridge.interrupt());
                  } else if (!_voiceBarWithMessages) {
                    FocusScope.of(context).unfocus();
                    setState(() => _voiceBarWithMessages = true);
                  }
                },
              ),
              const SizedBox(width: 20),
              _VoiceButton(
                icon: Icons.keyboard_rounded,
                onTap: () {
                  final msgs = _messages.isNotEmpty || _isThinking;
                  setState(() {
                    if (msgs) {
                      _voiceBarWithMessages = false;
                    } else {
                      _showTextInput = true;
                    }
                  });
                  _stt.stop();
                  if (msgs) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _chatInputFocusNode.requestFocus();
                    });
                  }
                },
              ),
            ],
          ),
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

    // 不渲染空内容 AI 消息（streaming 启动前的空白帧）
    if (!isUser && msg.content.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }

    return _BubbleWithTimestamp(
      isUser: isUser,
      timestamp: msg.createdAt,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,  // 头像始终对齐顶部
          children: [
            if (!isUser) ...[
              _ipAvatarWidget(agentId: widget.agentId, size: 32),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser ? _kInputFieldBluePurple : null,
                  color: isUser ? null : _kPartnerReplyBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? const Color(0xFF6B9DFF).withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isStreaming
                    ? _StreamingText(
                        content: msg.content,
                        textColor: Colors.white,
                      )
                    : Text(
                        msg.content,
                        style: const TextStyle(
                          color: Colors.white,
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
          _ipAvatarWidget(agentId: widget.agentId, size: 32),
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
                      color: StarpathColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: StarpathColors.outlineVariant,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BouncingDots(colors: gradColors),
                        if (hasThinkingText) ...[
                          const SizedBox(width: 8),
                          const Text(
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
                      color: StarpathColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: StarpathColors.outlineVariant,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _thinkingContent,
                      style: const TextStyle(
                        fontSize: 12,
                        color: StarpathColors.onSurfaceVariant,
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

  Widget _buildQuickSuggestChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (emoji, text) in _kChatQuickSuggests)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _messageController.text = text;
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: text.length),
                      );
                      setState(() {});
                      _chatInputFocusNode.requestFocus();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: StarpathColors.surfaceContainer
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: StarpathColors.outlineVariant,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 16, height: 1.2),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: StarpathColors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(Color gradStart, Color gradEnd) {
    final showQuickSuggests = _showTextInput || _messages.isNotEmpty;
    final hasMsgs = _messages.isNotEmpty || _isThinking;

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
            color: StarpathColors.surfaceBright.withValues(alpha: 0.38),
            border: const Border(
              top: BorderSide(
                color: StarpathColors.divider,
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showQuickSuggests)
                _buildQuickSuggestChips()
                    .animate()
                    .fadeIn(duration: 220.ms, curve: Curves.easeOut)
                    .slideY(
                      begin: 0.06,
                      duration: 240.ms,
                      curve: Curves.easeOutCubic,
                    ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 沉浸模式下显示「收起键盘」返回三按钮
                  if (_showTextInput && _messages.isEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _showTextInput = false);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StarpathColors.surfaceContainerHigh
                              .withValues(alpha: 0.8),
                          border: Border.all(
                              color: StarpathColors.outlineVariant, width: 0.8),
                        ),
                        child: const Icon(Icons.keyboard_hide_rounded,
                            size: 18, color: StarpathColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                  // ── 麦克风：有消息时点击一次切回底部语音界面 ───────────────────
                  GestureDetector(
                    onTap: hasMsgs
                        ? () {
                            FocusScope.of(context).unfocus();
                            setState(() => _voiceBarWithMessages = true);
                          }
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: _MicButton(
                      available: _sttAvailable,
                      listening: _stt.isListening,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FocusInputField(
                      controller: _messageController,
                      focusNode: _chatInputFocusNode,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (_, value, __) => _SendButton(
                      canSend: !_isThinking && value.text.trim().isNotEmpty,
                      gradStart: gradStart,
                      gradEnd: gradEnd,
                      onSend: _sendMessage,
                    ),
                  ),
                ],
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
  final _ChatConnUi status;
  const _OnlineDot({required this.status});

  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ripple;

  bool get _live => widget.status == _ChatConnUi.live;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ripple = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (_live) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_OnlineDot old) {
    super.didUpdateWidget(old);
    if (_live && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!_live && _ctrl.isAnimating) {
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
    final color = switch (widget.status) {
      _ChatConnUi.live => StarpathColors.success,
      _ChatConnUi.demo => StarpathColors.warning,
      _ChatConnUi.connecting => StarpathColors.textTertiary,
    };

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_live)
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
        clipBehavior: Clip.none,
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

// ── 聚焦边框输入框（蓝紫渐变底）────────────────────────────────────────────────

const _kInputFieldBluePurple = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF6B9DFF),
    Color(0xFF6366F1),
    Color(0xFF9B72FF),
  ],
  stops: [0.0, 0.48, 1.0],
);

class _FocusInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  const _FocusInputField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  State<_FocusInputField> createState() => _FocusInputFieldState();
}

class _FocusInputFieldState extends State<_FocusInputField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusNodeChange);
  }

  void _onFocusNodeChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusNodeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: StarpathColors.surfaceContainerHigh,
        border: Border.all(
          color: _focused
              ? StarpathColors.primary.withValues(alpha: 0.45)
              : StarpathColors.outlineVariant.withValues(alpha: 0.5),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: '输入消息...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.transparent,
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
            borderSide: BorderSide.none,
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
                  : StarpathColors.surfaceContainerHighest
                      .withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: !widget.canSend
                  ? Border.all(
                      color: StarpathColors.outlineVariant,
                      width: 0.8,
                    )
                  : null,
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
                    : StarpathColors.onSurfaceVariant.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 输入栏语音 / 语言入口：蓝紫渐变（底圈 + 图标 glyph）────────────────────────

class _MicButton extends StatefulWidget {
  final bool available;
  final bool listening;

  const _MicButton({
    required this.available,
    this.listening = false,
  });

  /// 聊天栏语音入口统一蓝紫渐变（与主题 accent 协调）
  static const LinearGradient _bluePurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6B9DFF),
      Color(0xFF6366F1),
      Color(0xFF9B72FF),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  @override
  Widget build(BuildContext context) {
    const g = _MicButton._bluePurpleGradient;
    final shadowColor = const Color(0xFF6366F1).withValues(alpha: 0.38);
    final active = widget.available && widget.listening;

    return AnimatedScale(
      scale: active ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: widget.available ? g : null,
          color: widget.available
              ? null
              : StarpathColors.surfaceContainerHigh.withValues(alpha: 0.8),
          border: Border.all(
            color: widget.available
                ? Colors.white.withValues(alpha: active ? 0.35 : 0.22)
                : StarpathColors.outlineVariant,
            width: 0.8,
          ),
          boxShadow: widget.available
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: active ? 0.55 : 0.38),
                    blurRadius: active ? 16 : 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            Icons.mic_rounded,
            size: 19,
            color: widget.available
                ? Colors.white
                : StarpathColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ── 沉浸式底部三按钮 ──────────────────────────────────────────────────────────

class _VoiceButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;

  /// 与输入栏语音按钮一致的蓝紫渐变（中间麦克风状态）
  static const LinearGradient kHighlightBluePurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6B9DFF),
      Color(0xFF6366F1),
      Color(0xFF9B72FF),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  const _VoiceButton({
    required this.icon,
    this.onTap,
    this.highlight = false,
  });

  @override
  State<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<_VoiceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                widget.highlight ? _VoiceButton.kHighlightBluePurple : null,
            color: widget.highlight
                ? null
                : StarpathColors.surfaceContainerHigh.withValues(alpha: 0.85),
            border: Border.all(
              color: widget.highlight
                  ? Colors.white.withValues(alpha: 0.22)
                  : StarpathColors.outlineVariant,
              width: 0.8,
            ),
            boxShadow: widget.highlight
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.42),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 26,
            color: widget.highlight
                ? Colors.white
                : StarpathColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 底部菜单选项行 ──────────────────────────────────────────────────────────

class _PartnerOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _PartnerOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
