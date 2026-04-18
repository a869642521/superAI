import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/constants.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/data/main_partner_provider.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';
import 'package:starpath/features/chat/presentation/chat_assistant_markdown.dart';
import 'package:starpath/features/chat/presentation/voice_plain_util.dart';
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
/// 语音伙伴页：在 [_kChatHeroVideoScaleFactor] 基础上再缩小为 0.9 倍
const double _kChatHeroVideoVoiceExtraScale = 0.9;
/// 语音伙伴页：背景视频整体上移（逻辑像素）
const double _kChatHeroVideoOffsetY = -20;

/// AI 伙伴对话页全屏底色
const Color _kChatPageBackground = Color(0xFF18082A);

/// 语音沉浸页欢迎文案距内容区顶（顶栏下方，与示意红框区域对齐）
const double _kImmersiveContentTop = 12;

/// 语音聆听提示：无底色，文案与动效点为浅紫（与 [StarpathColors.secondary] 一致）

/// 是否显示全屏角色背景视频。
const bool _kShowChatHeroVideo =
    bool.fromEnvironment('SHOW_CHAT_HERO_VIDEO', defaultValue: true);

/// 伙伴回复气泡底色（不透明）
const Color _kPartnerReplyBubbleColor = Color(0xFF341545);


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

/// 聊天页入口模式
enum ChatEntryMode {
  /// 默认：语音沉浸模式（全屏视频 + 三按钮语音控制栏）
  voice,
  /// 纯文字聊天模式（从语音页键盘按钮跳转而来，无背景视频）
  text,
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

  /// 初始进入模式：voice（默认语音沉浸）或 text（纯文字聊天）
  final ChatEntryMode initialMode;

  const ChatDetailPage({
    super.key,
    this.conversationId,
    this.agentId,
    this.helloVideo,
    this.haitVideo,
    this.breatheVideo,
    this.downVideo,
    this.agentName,
    this.initialMode = ChatEntryMode.voice,
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
  /// TTS / 火山实时语音播放时暂停背景 MP4，避免与麦克风/扬声器争用解码器与音频焦点（模拟器上尤其明显）
  bool _bgPausedForExternalAudio = false;

  // ── 语音识别（默认连续聆听，无弹窗）──────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  /// 沉浸页实时识别文案（有消息时也可在后台识别并自动发送）
  String _voiceTranscript = '';
  /// dispose 开始时立即置 true，所有 async 回调检查此标志后才 setState
  bool _disposed = false;
  /// Android 报 `error_speech_timeout` + permanent 后若立刻再 listen，会「准备就绪↔正在聆听」死循环
  DateTime? _sttCooldownUntil;
  Timer? _sttResumeTimer;
  Timer? _sttCooldownEndsTimer;

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
  /// Volc SDK 连接状态：null=未初始化/连接中，true=已连接，false=连接失败
  bool? _volcConnected;
  /// Volc SDK 最近一次错误信息（用于 UI 提示）
  String? _volcLastError;
  /// 已通过 SDK 收到的 AI 回复文本（流式拼接）
  String _sdkAiBuffer = '';
  /// 本轮 Volc 用户话（userFinalText 时记录，aiRoundDone 时落库）
  String _volcCurrentUserText = '';

  /// 系统 STT：同一次聆听里取「更完整」的识别串；终稿 debounce 后再发，避免 final 早于整句
  String _sttSessionBest = '';
  Timer? _sttFinalizeTimer;

  /// 是否走火山端到端实时语音 SDK。
  /// 与「统一大脑」（STT→Socket→LLM→TTS 落库）并存会分叉上下文，故需同时开启：
  /// `--dart-define=VOLC_VOICE_SDK=true --dart-define=VOLC_E2E_VOICE=true`
  static const bool _useVolcSdk =
      bool.fromEnvironment('VOLC_VOICE_SDK', defaultValue: false) &&
      bool.fromEnvironment('VOLC_E2E_VOICE', defaultValue: false);
  static const String _volcAppId =
      String.fromEnvironment('VOLC_APP_ID', defaultValue: '');
  static const String _volcAppKey =
      String.fromEnvironment('VOLC_APP_KEY', defaultValue: '');
  /// Access Token（控制台「服务接口认证信息」）
  static const String _volcAppToken =
      String.fromEnvironment('VOLC_APP_TOKEN', defaultValue: '');
  /// StartSession 必传 model：O2.0 → 1.2.1.1，SC2.0 → 2.2.0.0
  static const String _volcDialogModel =
      String.fromEnvironment('VOLC_DIALOG_MODEL', defaultValue: '1.2.1.1');
  /// O 系列默认 vv 音色；SC/SC2 需换文档所列 ICL_/saturn_ 音色并与 model 匹配
  static const String _volcTtsSpeaker = String.fromEnvironment(
    'VOLC_TTS_SPEAKER',
    defaultValue: 'zh_female_vv_jupiter_bigtts',
  );
  /// AEC 回声消除：真机扬声器开启，戴耳机或模拟器关闭
  static const bool _volcEnableAec =
      bool.fromEnvironment('VOLC_ENABLE_AEC', defaultValue: false);

  /// 无历史消息且未切键盘：展示底部语音沉浸栏；有历史消息：始终可语音。
  /// WebSocket 未连上但 REST 已拿到会话时，不再显示「连接中」。
  _ChatConnUi get _connUi {
    if (_isConnected) return _ChatConnUi.live;
    if (_conversation != null) return _ChatConnUi.demo;
    return _ChatConnUi.connecting;
  }

  /// 用于打开「调整性格」等需要真实 agentId 的入口。
  String? get _resolvedAgentId {
    final fromWidget = widget.agentId?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    final fromConv = _conversation?.agentId.trim();
    if (fromConv != null && fromConv.isNotEmpty) return fromConv;
    return null;
  }

  /// 从文字页返回时刷新语音页消息列表，避免两页内容衔接不上
  Future<void> _refreshMessagesFromServer() async {
    final convId = _conversation?.id ?? widget.conversationId;
    if (convId == null || convId.isEmpty || _disposed || !mounted) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages = await repo.getMessages(convId);
      if (!mounted || _disposed) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages.reversed);
        _settledCount = _messages.length;
      });
      _scrollToBottom();
    } catch (_) {
      // 刷新失败静默忽略，不影响正常使用
    }
  }

  Future<void> _reloadConversationSnapshot() async {
    final conv = _conversation;
    if (conv == null) return;
    try {
      final convs = await ref.read(conversationsProvider.future);
      for (final c in convs) {
        if (c.id == conv.id) {
          if (mounted) setState(() => _conversation = c);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _openPartnerPersonalityEditor() async {
    final id = _resolvedAgentId;
    if (id == null || id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前无法识别伙伴，请稍后再试')),
        );
      }
      return;
    }
    final changed = await context.push<bool>('/agents/$id/personality');
    if (changed == true && mounted) {
      ref.invalidate(myAgentsProvider);
      ref.invalidate(conversationsProvider);
      await _reloadConversationSnapshot();
    }
  }

  bool get _shouldRunContinuousVoice =>
      _sttAvailable &&
      _conversation != null &&
      !_ttsPlaying &&        // TTS 说话时暂停，避免把 AI 音频当用户输入
      !_isThinking &&        // AI 思考时暂停，减少不必要的音频冲突
      (_messages.isNotEmpty || !_showTextInput);

  bool get _isTextMode => widget.initialMode == ChatEntryMode.text;

  /// 语音页点键盘进入的全屏文字聊天：与 [widget.initialMode] 独立，不新开 Route，
  /// 避免第二个 Socket / 第二份 [_messages] 与语音页「接不上」。
  bool _inlineTextMode = false;

  bool get _showFullTextChat =>
      widget.initialMode == ChatEntryMode.text || _inlineTextMode;

  @override
  void initState() {
    super.initState();
    // text 模式：直接进入文字聊天，不启动语音、不加载视频
    if (_isTextMode) {
      _showTextInput = true;
      _voiceBarWithMessages = false;
    } else {
      if (_useVolcSdk) {
        _initVolcVoice();
      } else {
        _initStt();
        _initTts();
      }
      if (_kShowChatHeroVideo) {
        _initBgVideo();
      }
    }
    // text 模式延迟加载：等待语音页可能正在进行的 saveTurn 落库
    _loadConversation(delayed: _isTextMode);
  }

  // ── 视频初始化 ─────────────────────────────────────────────────────────────

  static final VideoPlayerOptions _kBgVideoPlayerOptions = VideoPlayerOptions(
    mixWithOthers: true,
  );

  VideoPlayerController _makeCtrl(String asset) => kIsWeb
      ? VideoPlayerController.networkUrl(
          Uri.parse('assets/$asset'),
          videoPlayerOptions: _kBgVideoPlayerOptions,
        )
      : VideoPlayerController.asset(
          asset,
          videoPlayerOptions: _kBgVideoPlayerOptions,
        );

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
    // 只使用 widget 传入的素材，无传入则跳过（避免加载不存在的默认资源崩溃）
    final helloAsset   = widget.helloVideo;
    final haitAsset    = widget.haitVideo;
    final breatheAsset = widget.breatheVideo;
    final downAsset    = widget.downVideo;

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
        _downCtrl?.pause();
    }
  }

  /// 暂停四条背景视频（任意正在播放的），供 TTS / 实时语音与 STT 争用时调用。
  /// 仅 pause，不移除阶段 tick 监听器，避免恢复后无法 hello→hait→breathe 切换。
  void _pauseBgVideoForExternalAudio() {
    if (!_videoReady || _bgPausedForExternalAudio) return;
    final ctrls = [_helloCtrl, _haitCtrl, _breatheCtrl, _downCtrl];
    final anyPlaying = ctrls.any((c) => c?.value.isPlaying ?? false);
    if (!anyPlaying) return;
    _bgPausedForExternalAudio = true;
    for (final c in ctrls) {
      c?.pause();
    }
  }

  /// 与 [_pauseBgVideoForExternalAudio] 成对：按当前 [_videoPhase] 恢复播放。
  void _resumeBgVideoAfterExternalAudio() {
    if (!_bgPausedForExternalAudio || _disposed) return;
    _bgPausedForExternalAudio = false;
    if (!mounted || !_videoReady) return;
    switch (_videoPhase) {
      case _ChatVideoPhase.hello:
        unawaited(_helloCtrl?.play());
      case _ChatVideoPhase.hait:
        unawaited(_haitCtrl?.play());
      case _ChatVideoPhase.breathe:
        unawaited(_breatheCtrl?.play());
      case _ChatVideoPhase.down:
        unawaited(_downCtrl?.play());
    }
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onStatus: _onSttStatus,
      onError: _onSttError,
    );
    if (!ok) {
      debugPrint(
        '[STT] speech_to_text 初始化失败（常见：模拟器无麦克风、未授权麦克风/语音识别）',
      );
    }
    _safeSetState(() => _sttAvailable = ok);
    // 会话加载后 _maybeStartListening 会再触发一次；这里提前试一次
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _maybeStartListening();
    }
  }

  // ── STT 状态回调（事件驱动替代 while 轮询）───────────────────────────────────

  /// `speech_to_text` 状态：'listening' | 'notListening' | 'done' | 'doneNoResult'
  void _onSttStatus(String status) {
    _safeSetState(() {}); // 刷新麦克风 UI
    if (_disposed || !mounted) return;
    // notListening 与 done 往往接连到达：合并为一次防抖重启，避免双重 listen
    if (status == 'done' ||
        status == 'notListening' ||
        status == 'doneNoResult') {
      _scheduleResumeSttAfterSessionEnd();
    }
  }

  void _onSttError(SpeechRecognitionError err) {
    debugPrint('[STT] platform error: $err');
    _sttResumeTimer?.cancel();
    _sttResumeTimer = null;
    _sttCooldownEndsTimer?.cancel();
    final msg = err.errorMsg.toLowerCase();
    final noSpeech = msg.contains('timeout') ||
        msg.contains('no_match') ||
        msg.contains('speech_timeout');
    final longCooldown = err.permanent || noSpeech;
    final cool = longCooldown ? const Duration(seconds: 14) : const Duration(seconds: 3);
    _sttCooldownUntil = DateTime.now().add(cool);
    _sttCooldownEndsTimer = Timer(cool + const Duration(milliseconds: 120), () {
      _sttCooldownEndsTimer = null;
      if (_disposed || !mounted) return;
      _sttCooldownUntil = null;
      _safeSetState(() {});
      _maybeStartListening();
    });
    _safeSetState(() {});
  }

  /// 会话正常结束（非 error 路径）后防抖再 listen，合并 notListening + done。
  void _scheduleResumeSttAfterSessionEnd() {
    _sttResumeTimer?.cancel();
    _sttResumeTimer = Timer(const Duration(milliseconds: 600), () {
      _sttResumeTimer = null;
      if (_disposed || !mounted) return;
      _maybeStartListening();
    });
  }

  /// 用户点麦克风：取消冷却并尝试重新打开识别（应对模拟器/系统卡死）
  void _userRetryListening() {
    _sttResumeTimer?.cancel();
    _sttResumeTimer = null;
    _sttCooldownEndsTimer?.cancel();
    _sttCooldownEndsTimer = null;
    _sttCooldownUntil = null;
    unawaited(_stt.stop());
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!_disposed && mounted) _maybeStartListening();
    });
  }

  /// 幂等：满足条件且未在聆听时启动 STT（多处调用安全，不会重复开启）
  void _maybeStartListening() {
    if (_disposed || !mounted || !_sttAvailable) return;
    final until = _sttCooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    if (_stt.isListening || !_shouldRunContinuousVoice) return;
    unawaited(_stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 5),
      // 停顿略长：减少「句中停顿被当成说完」导致 final 只有几个字
      pauseFor: const Duration(seconds: 16),
      localeId: 'zh_CN',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    ));
  }

  /// 幂等：条件不满足时停止 STT
  void _stopListeningIfActive() {
    if (_stt.isListening) unawaited(_stt.stop());
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        _safeSetState(() => _ttsPlaying = true);
        _stopListeningIfActive(); // TTS 开口时停 STT，防止 AI 声音被当作用户输入
        _pauseBgVideoForExternalAudio(); // 停背景 MP4，减轻与 TTS 的解码/音频会话争用
      });
      _tts.setCompletionHandler(() {
        _safeSetState(() => _ttsPlaying = false);
        _resumeBgVideoAfterExternalAudio();
        _maybeStartListening(); // TTS 说完后重启 STT
      });
      _tts.setCancelHandler(() {
        _safeSetState(() => _ttsPlaying = false);
        _resumeBgVideoAfterExternalAudio();
        _maybeStartListening();
      });
      _tts.setErrorHandler((msg) {
        debugPrint('[TTS] error: $msg');
        _safeSetState(() => _ttsPlaying = false);
        _resumeBgVideoAfterExternalAudio();
        _maybeStartListening();
      });
      _safeSetState(() => _ttsReady = true);
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
    }
  }

  // ── 火山引擎 SDK 实时对话 ────────────────────────────────────────────────────

  Future<void> _initVolcVoice() async {
    if (_volcAppId.isEmpty || _volcAppToken.isEmpty) {
      debugPrint('[VolcVoice] 缺少 VOLC_APP_ID 或 VOLC_APP_TOKEN，回退 STT+TTS');
      await _initStt();
      await _initTts();
      return;
    }
    debugPrint(
      '[VolcVoice] 启动 dialogModel=$_volcDialogModel speaker=$_volcTtsSpeaker',
    );
    await _voiceBridge.prepareEnvironment();
    _voiceBridgeSub = _voiceBridge.events.listen(_onVolcEvent);
    final ok = await _voiceBridge.startDialog(const VoiceDialogConfig(
      appId:       _volcAppId,
      appKey:      _volcAppKey,
      appToken:    _volcAppToken,
      dialogModel: _volcDialogModel,
      ttsSpeaker:  _volcTtsSpeaker,
      enableAec:   _volcEnableAec,
    ));
    if (!ok && mounted) {
      debugPrint('[VolcVoice] startDialog failed, fallback to STT/TTS');
      _safeSetState(() => _volcConnected = false);
      await _initStt();
      await _initTts();
    }
  }

  void _onVolcEvent(VoiceDialogEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case VoiceDialogEventType.connected:
        debugPrint('[VolcVoice] connected');
        _safeSetState(() => _volcConnected = true);

      case VoiceDialogEventType.userSpeaking:
        _safeSetState(() => _voiceTranscript = event.text ?? '');

      case VoiceDialogEventType.userFinalText:
        final text = (event.text ?? '').trim();
        if (text.isEmpty) break;
        // SDK 可能先发短终稿再发整句：首条后 _isThinking 已为 true，必须把后续更长的
        // userFinal 合并进同一条用户气泡，否则库里只剩几个字。
        final last = _messages.isNotEmpty ? _messages.last : null;
        final refiningUser =
            last != null && last.isUser && !_sdkAiSpeaking;
        if (!_isThinking) {
          _volcCurrentUserText = text;
          _safeSetState(() {
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
        } else if (refiningUser) {
          final merged = _preferRicherTranscript(last.content, text);
          if (merged != last.content) {
            _volcCurrentUserText = merged;
            _safeSetState(() {
              _messages[_messages.length - 1] = MessageModel(
                id: last.id,
                role: last.role,
                content: merged,
                voicePlain: last.voicePlain,
                createdAt: last.createdAt,
              );
            });
            _scrollToBottom();
          }
        } else if (text.length > _volcCurrentUserText.length) {
          _volcCurrentUserText = text;
        }

      case VoiceDialogEventType.aiSpeaking:
        // 不再在此处触发 down 视频重播：会与实时语音并发占用 MediaCodec/音频焦点，
        // 模拟器上易出现 aac/h264 buffer discard、语音断续。需要 down 动画可用户点热区触发。
        _pauseBgVideoForExternalAudio();
        _safeSetState(() {
          _sdkAiSpeaking = true;
          _sdkAiBuffer = '';
          if (_messages.isEmpty || _messages.last.isUser) {
            _messages.add(MessageModel(
              role: 'assistant',
              content: '',
              createdAt: DateTime.now(),
            ));
          }
        });

      case VoiceDialogEventType.aiTextDelta:
        final delta = event.text ?? '';
        if (delta.isNotEmpty) {
          _safeSetState(() {
            _sdkAiBuffer += delta;
            // 防御：若 AI 消息占位尚未创建（aiSpeaking 未到或乱序），补创建
            if (_messages.isEmpty || _messages.last.isUser) {
              _isThinking = false;
              _sdkAiSpeaking = true;
              _messages.add(MessageModel(
                role: 'assistant',
                content: _sdkAiBuffer,
                createdAt: DateTime.now(),
              ));
            } else {
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
        _safeSetState(() {
          _sdkAiSpeaking = false;
          _isThinking = false;
          _settledCount = _messages.length;
        });
        HapticFeedback.lightImpact();
        // 把本轮用户话 + AI 回复同步落库（保证与文字对话共享同一会话历史）
        _saveVolcTurnToBackend();
        ref.invalidate(conversationsProvider);
        _resumeBgVideoAfterExternalAudio();

      case VoiceDialogEventType.interrupted:
        _safeSetState(() => _sdkAiSpeaking = false);
        _resumeBgVideoAfterExternalAudio();

      case VoiceDialogEventType.error:
        debugPrint('[VolcVoice] error: ${event.errorMessage}');
        _safeSetState(() {
          _isThinking = false;
          _sdkAiSpeaking = false;
          _volcConnected = false;
          _volcLastError = event.errorMessage;
        });
        _resumeBgVideoAfterExternalAudio();

      case VoiceDialogEventType.disconnected:
        _safeSetState(() {
          _sdkAiSpeaking = false;
          _isThinking = false;
          _volcConnected = false;
        });
        _resumeBgVideoAfterExternalAudio();
    }
  }

  Future<void> _stopAssistantSpeech() async {
    try {
      await _tts.stop();
      _safeSetState(() => _ttsPlaying = false);
      _resumeBgVideoAfterExternalAudio();
    } catch (_) {}
  }

  Future<void> _speakAssistantReplyIfNeeded() async {
    final should = _pendingSpeakAssistantReply;
    _pendingSpeakAssistantReply = false;
    if (!should || !_ttsReady || !mounted) return;
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.isUser) return;
    final text = voicePlainForMessage(last);
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

  /// Volc 端到端每轮结束后把用户话 + AI 回复写入后端，保证会话历史同步。
  void _saveVolcTurnToBackend() {
    final userText = _volcCurrentUserText.trim();
    final aiText = _sdkAiBuffer.trim();
    _volcCurrentUserText = '';
    if (userText.isEmpty || aiText.isEmpty) return;
    final authState = ref.read(authProvider);
    final userId = authState.userId ?? '';
    final convId = _conversation?.id ?? widget.conversationId ?? '';
    if (convId.isEmpty) return;
    _socket?.emit('saveTurn', {
      'conversationId': convId,
      'userId': userId,
      'userText': userText,
      'assistantText': aiText,
    });
  }

  /// 再次朗读最近一条助手回复（口语化文本 / voicePlain）
  Future<void> _replayLastAssistantTts() async {
    if (_messages.isEmpty || _useVolcSdk || !_ttsReady) return;
    final last = _messages.last;
    if (!last.isAssistant) return;
    final text = voicePlainForMessage(last);
    if (text.isEmpty) return;
    _pendingSpeakAssistantReply = false;
    await _stopAssistantSpeech();
    if (!mounted) return;
    try {
      await _stt.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TTS] replay speak failed: $e');
      if (mounted) setState(() => _ttsPlaying = false);
    }
  }

  String _voiceAssistantSubtitleLive() {
    if (_isThinking && _streamingContent.trim().isNotEmpty) {
      return stripMarkdownForVoice(_streamingContent);
    }
    if (_messages.isEmpty) return '';
    final last = _messages.last;
    if (!last.isAssistant || last.content.trim().isEmpty) return '';
    return voicePlainForMessage(last);
  }

  bool _shouldShowVoiceAssistantSubtitle() {
    if (_useVolcSdk || _isTextMode) return false;
    if (_ttsPlaying) return true;
    if (_isThinking && _streamingContent.trim().isNotEmpty) return true;
    if (_messages.isEmpty) return false;
    final last = _messages.last;
    return last.isAssistant && last.content.trim().isNotEmpty;
  }

  /// 安全 setState：_disposed 置 true 后所有 async 路径均走此方法，
  /// 避免 widget 已 defunct 但 mounted 检查刚刚通过的 race condition。
  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) setState(fn);
  }

  /// 在 partial / 多次 final 之间选更完整的一句（常见：final 比最后 partial 还短）
  static String _preferRicherTranscript(String previous, String incoming) {
    final a = previous.trim();
    final b = incoming.trim();
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    if (b.startsWith(a) || a.startsWith(b)) {
      return a.length >= b.length ? a : b;
    }
    if (b.contains(a) && b.length > a.length) return b;
    if (a.contains(b) && a.length > b.length) return a;
    return b.length >= a.length ? b : a;
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_disposed || !mounted) return;
    final words = result.recognizedWords.trim();
    _safeSetState(() => _voiceTranscript = words.isEmpty ? _voiceTranscript : words);
    if (words.isNotEmpty) {
      _sttSessionBest = _preferRicherTranscript(_sttSessionBest, words);
    }
    if (!result.finalResult) return;

    _sttFinalizeTimer?.cancel();
    _sttFinalizeTimer = Timer(const Duration(milliseconds: 520), () {
      _sttFinalizeTimer = null;
      if (_disposed || !mounted) return;
      final t = _sttSessionBest.trim();
      _sttSessionBest = '';
      if (t.isEmpty || _isThinking) return;
      _sendVoiceMessage(t, speakAssistantReply: true);
      _safeSetState(() => _voiceTranscript = '');
    });
  }


  void _sendVoiceMessage(String text, {bool speakAssistantReply = false}) {
    if (text.isEmpty || _isThinking) return;

    _sttFinalizeTimer?.cancel();
    _sttFinalizeTimer = null;
    _sttSessionBest = '';

    _stopListeningIfActive(); // 立即停 STT，等 AI 回复完再重启
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
    // 最先置 true：所有还在飞的 async 回调（_continuousVoiceWorker、_onSpeechResult 等）
    // 通过 _disposed 提前跳出，彻底消除 "setState on defunct element" 断言。
    _disposed = true;
    _thinkingTimer?.cancel();
    _sttFinalizeTimer?.cancel();
    _sttResumeTimer?.cancel();
    _sttCooldownEndsTimer?.cancel();
    _bgPauseCurrent();
    _helloCtrl?.dispose();
    _haitCtrl?.dispose();
    _breatheCtrl?.dispose();
    _downCtrl?.removeListener(_bgOnDownTick);
    _downCtrl?.dispose();
    unawaited(_stt.stop());
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

  Future<void> _loadConversation({bool delayed = false}) async {
    // text 模式：若是从语音页跳转过来，saveTurn 可能还在落库中，
    // 延迟 600ms 再拉消息，保证能拿到最新一轮语音对话。
    if (delayed) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (_disposed || !mounted) return;
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
          _messages
            ..clear()
            ..addAll(messages.reversed);
          _settledCount = _messages.length;
        });
        _scrollToBottom();
        _connectSocket();
        // 会话就绪后激活 STT（此时 _conversation != null，条件满足）
        Future<void>.delayed(const Duration(milliseconds: 300), _maybeStartListening);
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
        Future<void>.delayed(const Duration(milliseconds: 300), _maybeStartListening);
      }
    }
  }

  void _connectSocket() {
    _socket?.dispose();
    final authState = ref.read(authProvider);
    final token = authState.token ?? '';
    final userId = authState.userId ?? '';

    final extraHeaders = <String, String>{
      'Authorization': 'Bearer $token',
      if (AppConstants.usesNgrokForApi) 'ngrok-skip-browser-warning': 'true',
    };

    _socket = io.io(
      '${AppConstants.wsBaseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(extraHeaders)
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
      debugPrint(
        '[ChatSocket] connect_error: $data\n'
        '  → 请确认宿主机已启动 Nest（端口 3000），且模拟器用 10.0.2.2 访问本机。\n'
        '  → 终端执行: make backend  或  cd server && npm run start:dev',
      );
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
            final prev = _messages.last;
            _messages[_messages.length - 1] = MessageModel(
              id: prev.id,
              role: 'assistant',
              content: _streamingContent,
              voicePlain: prev.voicePlain,
              createdAt: prev.createdAt,
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

    _socket!.on('messageComplete', (raw) {
      String? voicePlain;
      if (raw is Map) {
        final m = Map<dynamic, dynamic>.from(raw);
        final vp = m['voicePlain'];
        if (vp is String && vp.trim().isNotEmpty) {
          voicePlain = vp.trim();
        }
      }
      if (mounted) {
        setState(() {
          if (voicePlain != null &&
              _messages.isNotEmpty &&
              !_messages.last.isUser) {
            final last = _messages.last;
            _messages[_messages.length - 1] = MessageModel(
              id: last.id,
              role: last.role,
              content: last.content,
              voicePlain: voicePlain,
              createdAt: last.createdAt,
            );
          }
          _isThinking = false;
          _streamingContent = '';
          _thinkingContent = '';
          _settledCount = _messages.length;
        });
        HapticFeedback.lightImpact();
        ref.invalidate(conversationsProvider);
        unawaited(_speakAssistantReplyIfNeeded());
        // 若无 TTS（或 TTS 极短暂），也确保 STT 能恢复
        // TTS 路径：setStartHandler 停 STT → setCompletionHandler 重启
        // 无 TTS 路径：直接重启
        Future<void>.delayed(const Duration(milliseconds: 200), _maybeStartListening);
      }
    });

    // saveTurn 落库确认：语音端到端每轮结束后写库成功，刷新会话列表
    _socket!.on('turnSaved', (data) {
      if (mounted) {
        ref.invalidate(conversationsProvider);
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

    // ── text 模式 / 语音页内联全屏文字：同一 State，共享 Socket 与消息列表 ─────
    if (_showFullTextChat) {
      return _buildTextModeScaffold(agent, gradStart, gradEnd);
    }

    // ── voice 模式：沉浸语音布局 ─────────────────────────────────────────
    final showTextInputBar =
        (_messages.isNotEmpty || _isThinking)
            ? !_voiceBarWithMessages
            : _showTextInput;

    // 是否处于"键盘/文字输入"模式（此时返回键应退回语音模式，而非退出页面）
    final isInTextMode2 = _showTextInput || !_voiceBarWithMessages;

    return PopScope(
      canPop: !isInTextMode2,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 拦截返回：退出文字模式，回到语音沉浸界面
        FocusScope.of(context).unfocus();
        setState(() {
          _showTextInput = false;
          _voiceBarWithMessages = true;
        });
        if (!_useVolcSdk && _sttAvailable) _maybeStartListening();
      },
      child: Scaffold(
      backgroundColor: _kChatPageBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
              child: ColoredBox(color: _kChatPageBackground)),
          // ── 角色视频：黑底抠 alpha + ShaderMask 滤色与渐变 shader 混合 ───
          if (_kShowChatHeroVideo && _videoReady)
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
                  final scale = coverScale *
                      _kChatHeroVideoScaleFactor *
                      _kChatHeroVideoVoiceExtraScale;
                  // 直接显示原始视频，不做任何颜色滤镜或抠像处理
                  final Widget videoCore = VideoPlayer(ctrl);
                  return Transform.translate(
                    offset: const Offset(0, _kChatHeroVideoOffsetY),
                    child: ClipRect(
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            width: videoSize.width,
                            height: videoSize.height,
                            child: videoCore,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // 视频全程可见，不加遮罩
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
                        if (_kShowChatHeroVideo && _videoReady)
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
                        _buildImmersiveView(),
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
      ), // Scaffold
    ); // PopScope
  }

  // ── 自定义顶栏 ────────────────────────────────────────────────────────────

  /// 与 Spotlight 长卡片 [agentName] 一致；无 query 时再显示会话里的 Agent 名。
  // ── 纯文字聊天模式 Scaffold ──────────────────────────────────────────────

  Widget _buildTextModeScaffold(
      AgentBrief? agent, Color gradStart, Color gradEnd) {
    Future<void> leaveTextChat() async {
      FocusScope.of(context).unfocus();
      if (_inlineTextMode) {
        setState(() => _inlineTextMode = false);
        await _refreshMessagesFromServer();
        if (_useVolcSdk && mounted && !_disposed) {
          await _restartVolcDialogOnly();
        }
      } else {
        Navigator.of(context).pop();
      }
    }

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0F0A1A),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── 顶栏 ──────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  // 返回：内联模式回到语音沉浸；独立文字页则 pop Route
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: Colors.white),
                    onPressed: () => unawaited(leaveTextChat()),
                  ),
                  const SizedBox(width: 4),
                  // 头像
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [gradStart, gradEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _topBarAgentEmoji(agent),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _topBarAgentTitle(agent),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_resolvedAgentId != null) ...[
                    IconButton(
                      tooltip: '调整性格',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        unawaited(_openPartnerPersonalityEditor());
                      },
                      icon: const Icon(Icons.psychology_alt_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── 消息列表 ───────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty && !_isThinking
                ? Center(
                    child: Text(
                      '发送消息开始对话',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
                    ),
                  )
                : _buildChatBody(agent, gradStart, gradEnd),
          ),
          // ── 输入栏 ─────────────────────────────────────────────────────
          _buildInputBar(gradStart, gradEnd),
        ],
      ),
    );

    if (_inlineTextMode) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(leaveTextChat());
        },
        child: scaffold,
      );
    }
    return scaffold;
  }

  /// 从全屏文字返回语音后重新拉起豆包会话（[stopDialog] 后需显式 start）
  Future<void> _restartVolcDialogOnly() async {
    if (!_useVolcSdk || _disposed || !mounted) return;
    if (_volcAppId.isEmpty || _volcAppToken.isEmpty) return;
    final ok = await _voiceBridge.startDialog(VoiceDialogConfig(
      appId: _volcAppId,
      appKey: _volcAppKey,
      appToken: _volcAppToken,
      dialogModel: _volcDialogModel,
      ttsSpeaker: _volcTtsSpeaker,
      enableAec: _volcEnableAec,
    ));
    if (!ok && mounted) {
      debugPrint('[VolcVoice] _restartVolcDialogOnly: startDialog failed');
    }
  }

  /// 内联文字模式打开后稍等 saveTurn 落库再拉 REST，避免列表缺最后一轮语音
  Future<void> _syncMessagesAfterOpeningInlineText() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || !_inlineTextMode) return;
    await _refreshMessagesFromServer();
  }

  /// 取 agent emoji 头像
  String _topBarAgentEmoji(AgentBrief? agent) {
    if (agent == null) return '🤖';
    final id = agent.id;
    const emojis = ['🌟', '💫', '✨', '🎯', '🚀', '🎨', '🎵', '🌈'];
    final digits = RegExp(r'\d+').allMatches(id);
    if (digits.isNotEmpty) {
      final n = int.parse(digits.last.group(0)!);
      return emojis[n % emojis.length];
    }
    return '🤖';
  }

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
          if (_resolvedAgentId != null) ...[
            Tooltip(
              message: '调整性格',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  unawaited(_openPartnerPersonalityEditor());
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
                  child: const Icon(Icons.psychology_alt_rounded,
                      size: 20, color: StarpathColors.onSurface),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
              if (_resolvedAgentId != null) ...[
                _PartnerOptionTile(
                  icon: Icons.psychology_alt_rounded,
                  iconColor: StarpathColors.secondary,
                  label: '调整性格与对话',
                  subtitle: '性格标签、人设与说话风格',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    unawaited(_openPartnerPersonalityEditor());
                  },
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: StarpathColors.outlineVariant.withValues(alpha: 0.3),
                ),
              ],
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

  // ── 沉浸式欢迎区（标题 + 说明） ─────────────────────────────────────────

  String _immersiveWelcomeSubtitle() {
    return switch (_connUi) {
      _ChatConnUi.live =>
        '我已经准备好陪你啦，有什么想聊的尽管说～',
      _ChatConnUi.demo =>
        '当前未连上实时服务（演示模式），界面可先体验；完整对话需启动后端。',
      _ChatConnUi.connecting => '正在连接中，请稍候...',
    };
  }

  Widget _buildImmersiveWelcomeColumn() {
    final screenW = MediaQuery.sizeOf(context).width;
    final subtitle = _immersiveWelcomeSubtitle();
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: StarpathColors.onSurface,
          height: 1.1,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: StarpathColors.onSurfaceVariant,
          height: 1.35,
        );

    // 顶栏下方、偏上区域（与角色立绘错开），勿垂直居中压在角色上
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(200, screenW - 32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '嗨，你好！',
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: bodyStyle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题 + 简短说明（语音沉浸主页）
  Widget _buildImmersiveView() {
    return Positioned(
      top: _kImmersiveContentTop,
      left: 0,
      right: 0,
      bottom: 0,
      child: _buildImmersiveWelcomeColumn(),
    );
  }

  // ── 底部三按钮操作栏 ───────────────────────────────────────────────────────

  Widget _buildVoiceControls(Color gradStart, Color gradEnd) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final listening = _stt.isListening;
    final inCooldown = _sttCooldownUntil != null &&
        DateTime.now().isBefore(_sttCooldownUntil!);

    // ── STT 不可用时降级为「打字 + TTS 朗读」模式 ────────────────────────────
    // _sttAvailable 为 false 的原因不限于模拟器：权限被拒、系统语音服务不可用等也会失败。
    // flutter_tts 仍可用，故用文字输入替代连续聆听。
    final bool useTypeToSpeak = !_useVolcSdk && !_sttAvailable;

    if (useTypeToSpeak) {
      return Container(
        padding: EdgeInsets.only(bottom: bottom + 16, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_ttsPlaying)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up_rounded,
                        size: 16, color: gradStart.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text('AI 正在播报...',
                        style: TextStyle(
                            fontSize: 13,
                            color: gradStart.withValues(alpha: 0.8))),
                  ],
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  '语音听写未就绪（模拟器常不支持；真机请检查麦克风与语音识别权限）。'
                  '请在此输入文字，AI 会以语音播报回答。',
                  style: TextStyle(
                      fontSize: 12,
                      color: StarpathColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: StarpathColors.surface
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: StarpathColors.outlineVariant
                                .withValues(alpha: 0.4)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                            color: StarpathColors.onSurface, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '输入想说的话...',
                          hintStyle: TextStyle(
                              color: StarpathColors.textTertiary,
                              fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) {
                          final text = v.trim();
                          if (text.isNotEmpty) {
                            _sendVoiceMessage(text,
                                speakAssistantReply: true);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (_, val, __) {
                      final canSend =
                          val.text.trim().isNotEmpty && !_isThinking;
                      return GestureDetector(
                        onTap: canSend
                            ? () {
                                final text =
                                    _messageController.text.trim();
                                if (text.isNotEmpty) {
                                  _sendVoiceMessage(text,
                                      speakAssistantReply: true);
                                }
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: canSend
                                ? LinearGradient(
                                    colors: [gradStart, gradEnd])
                                : null,
                            color: canSend
                                ? null
                                : StarpathColors.outlineVariant
                                    .withValues(alpha: 0.3),
                          ),
                          child: Icon(
                            _isThinking
                                ? Icons.hourglass_empty_rounded
                                : Icons.send_rounded,
                            color: canSend
                                ? Colors.white
                                : StarpathColors.textTertiary,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _VoiceButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    // ── 状态提示文案 ─────────────────────────────────────────────
    final String hint;
    if (_useVolcSdk) {
      // 豆包端到端语音 SDK 模式
      if (_volcConnected == null) {
        hint = '豆包语音连接中...';
      } else if (_volcConnected == true) {
        hint = _sdkAiSpeaking ? 'AI 正在说话...' : '请直接说话，AI 正在聆听';
      } else {
        // 连接失败
        if (_volcLastError != null && _volcLastError!.isNotEmpty) {
          hint = '豆包连接失败：$_volcLastError';
        } else {
          hint = '语音服务连接失败，请检查网络与 API Key';
        }
      }
    } else {
      // 系统 STT 模式
      hint = inCooldown
          ? '未检测到语音，稍候自动继续聆听（也可点麦克风重试）'
          : (listening ? '正在聆听...' : '准备就绪，请直接说话...');
    }

    final showListenCard = _voiceTranscript.isEmpty &&
        ((_useVolcSdk &&
                _volcConnected != false &&
                !(_volcConnected == true && _sdkAiSpeaking)) ||
            (!_useVolcSdk && _sttAvailable && !inCooldown));

    return Container(
      padding: EdgeInsets.only(bottom: bottom + 24, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_shouldShowVoiceAssistantSubtitle()) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '语音播报',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: StarpathColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _voiceAssistantSubtitleLive(),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StarpathColors.onSurface,
                      fontSize: 14,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_ttsPlaying)
                        TextButton.icon(
                          onPressed: () => unawaited(_stopAssistantSpeech()),
                          icon: const Icon(Icons.stop_circle_outlined, size: 20),
                          label: const Text('停止播报'),
                          style: TextButton.styleFrom(
                            foregroundColor: StarpathColors.onSurface,
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _ttsReady && !_isThinking
                              ? () => unawaited(_replayLastAssistantTts())
                              : null,
                          icon: const Icon(Icons.volume_up_rounded, size: 20),
                          label: const Text('收听回复'),
                          style: TextButton.styleFrom(
                            foregroundColor: gradStart,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: showListenCard
                ? _VoiceListenHintCard(hint: hint)
                : Text(
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
                    if (!_useVolcSdk && _sttAvailable) _userRetryListening();
                  } else if (!_useVolcSdk && _sttAvailable) {
                    _userRetryListening();
                  }
                },
              ),
              const SizedBox(width: 20),
              _VoiceButton(
                icon: Icons.keyboard_rounded,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  // 先停豆包引擎，避免与文字输入 / WebSocket 并发抢麦克风与音频焦点
                  if (_useVolcSdk) {
                    await _voiceBridge.stopDialog();
                  }
                  if (!mounted) return;
                  setState(() => _inlineTextMode = true);
                  unawaited(_syncMessagesAfterOpeningInlineText());
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
                    : isUser
                        ? Text(
                            msg.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          )
                        : ChatAssistantMarkdown(data: msg.content),
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

    // Android 上 BackdropFilter 配合 OpenGL ES 模拟器会有渲染异常；跳过毛玻璃只保留底色。
    final bool useBlur =
        kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    final Widget inputBody = Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(
              top: BorderSide(
                color: Color(0x33CC97FF),
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
                  // text 独立页面模式：不显示「收起键盘」和「切回语音」麦克风按钮
                  if (!_showFullTextChat) ...[
                    // 沉浸模式下显示「收起键盘」返回三按钮
                    if (_showTextInput && _messages.isEmpty) ...[
                      GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _showTextInput = false);
                          _maybeStartListening();
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
                                color: StarpathColors.outlineVariant,
                                width: 0.8),
                          ),
                          child: const Icon(Icons.keyboard_hide_rounded,
                              size: 18,
                              color: StarpathColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                    // ── 麦克风：有消息时点击一次切回底部语音界面 ─────────────────
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
                  ],
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
        );

    if (!useBlur) return inputBody;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: inputBody,
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

// ── 聆听声波条（多竖条正弦叠加，模拟语音能量）────────────────────────────────

class _VoiceWaveBars extends StatefulWidget {
  final Color color;

  const _VoiceWaveBars({required this.color});

  @override
  State<_VoiceWaveBars> createState() => _VoiceWaveBarsState();
}

class _VoiceWaveBarsState extends State<_VoiceWaveBars>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 11;
  static const double _barWidth = 3.2;
  static const double _gap = 2.4;
  static const double _hMin = 4;
  static const double _hMax = 28;

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 每条柱独立相位 + 双频正弦，避免机械齐跳
  double _barHeight(int index, double t) {
    final phase = index * 0.52;
    final u = t * 2 * math.pi * 1.75;
    final w1 = math.sin(u + phase);
    final w2 = 0.42 * math.sin(u * 2.15 + phase * 1.3 + 0.8);
    final mix = (w1 + w2 + 1.42) / 2.84;
    return _hMin + (_hMax - _hMin) * mix.clamp(0.12, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return SizedBox(
          height: _hMax + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _barCount; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Container(
                  width: _barWidth,
                  height: _barHeight(i, t),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                      alpha: 0.55 + (i % 4) * 0.09,
                    ),
                    borderRadius:
                        BorderRadius.circular(_barWidth * 0.5),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 语音聆听提示（透明底 + 浅紫字 + 声波条）──────────────────────────────────

class _VoiceListenHintCard extends StatelessWidget {
  final String hint;

  const _VoiceListenHintCard({required this.hint});

  @override
  Widget build(BuildContext context) {
    const hintColor = StarpathColors.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _VoiceWaveBars(color: hintColor),
            const SizedBox(height: 14),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: hintColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
  // 动画对象在 initState 里创建一次，避免在 build() 里反复创建导致 listener 泄漏
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anims = List.generate(3, (i) {
      final begin = i * 0.28;
      final end = (begin + 0.50).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: -7).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(begin, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sz = 7.0;
    const gap = 6.0;
    final dotFill = widget.colors[0].withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _anims[i].value),
              child: Container(
                width: sz,
                height: sz,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotFill,
                ),
              ),
            ),
          ),
        ],
      ],
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
