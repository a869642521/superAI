import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── 事件类型 ─────────────────────────────────────────────────────────────────

enum VoiceDialogEventType {
  /// 连接成功，可以开始说话
  connected,

  /// 用户说话识别中（partial）
  userSpeaking,

  /// 用户一句话识别完整文本
  userFinalText,

  /// AI 开始说话（收到第一个 audio delta）
  aiSpeaking,

  /// AI 说话文本片段（streaming）
  aiTextDelta,

  /// AI 这一轮说话结束
  aiRoundDone,

  /// 用户打断 AI（AI 停止播放）
  interrupted,

  /// 发生错误
  error,

  /// 连接断开
  disconnected,
}

class VoiceDialogEvent {
  final VoiceDialogEventType type;
  final String? text;
  final String? errorMessage;

  const VoiceDialogEvent({
    required this.type,
    this.text,
    this.errorMessage,
  });

  @override
  String toString() => 'VoiceDialogEvent($type, text=$text, err=$errorMessage)';
}

// ── 配置 ─────────────────────────────────────────────────────────────────────

class VoiceDialogConfig {
  /// 控制台应用 AppID（必填，见 SDK 文档参数配置章节）
  final String appId;

  /// 控制台应用 AppKey / Secret Key（必填）
  final String appKey;

  /// 控制台应用 Access Token（必填）
  final String appToken;

  /// 固定值 "volc.speech.dialog"（端到端实时语音大模型）
  final String resourceId;

  /// StartSession 必传 model：O / O2.0 → 1.2.1.1；SC / SC2.0 → 2.2.0.0
  final String dialogModel;

  /// TTS 发音人（O 系列默认 vv，见文档 1594356）
  final String ttsSpeaker;

  /// AEC 回声消除：真机扬声器场景开启，戴耳机或模拟器关闭
  final bool enableAec;

  const VoiceDialogConfig({
    this.appId = '',
    this.appKey = '',
    this.appToken = '',
    this.resourceId = 'volc.speech.dialog',
    this.dialogModel = '1.2.1.1',
    this.ttsSpeaker = 'zh_female_vv_jupiter_bigtts',
    this.enableAec = false,
  });
}

// ── 桥接主类 ──────────────────────────────────────────────────────────────────

class VoiceDialogBridge {
  static const _methodChannel =
      MethodChannel('com.starpath/voice_dialog');
  static const _eventChannel =
      EventChannel('com.starpath/voice_dialog_events');

  StreamSubscription<dynamic>? _nativeSub;
  final _controller = StreamController<VoiceDialogEvent>.broadcast();

  /// 对话事件流，Flutter 侧 listen 即可
  Stream<VoiceDialogEvent> get events => _controller.stream;

  bool _started = false;

  // ── 公开 API ───────────────────────────────────────────────────────────────

  /// 初始化 SDK 环境（每个 App 生命周期调用一次）
  Future<void> prepareEnvironment() async {
    try {
      await _methodChannel.invokeMethod('prepareEnvironment');
    } catch (e) {
      debugPrint('[VoiceDialog] prepareEnvironment error: $e');
    }
  }

  /// 创建并启动对话引擎
  Future<bool> startDialog(VoiceDialogConfig config) async {
    if (_started) return true;
    _listenNativeEvents();
    try {
      final result = await _methodChannel.invokeMethod<bool>('startDialog', {
        'appId':       config.appId,
        'appKey':      config.appKey,
        'appToken':    config.appToken,
        'resourceId':  config.resourceId,
        'dialogModel': config.dialogModel,
        'ttsSpeaker':  config.ttsSpeaker,
        'enableAec':   config.enableAec,
      });
      _started = result == true;
      return _started;
    } on PlatformException catch (e) {
      final msg = '${e.code}: ${e.message ?? e.toString()}';
      debugPrint('[VoiceDialog] startDialog PlatformException: $msg');
      _controller.add(VoiceDialogEvent(
        type: VoiceDialogEventType.error,
        errorMessage: msg,
      ));
      return false;
    } catch (e) {
      debugPrint('[VoiceDialog] startDialog error: $e');
      _controller.add(VoiceDialogEvent(
        type: VoiceDialogEventType.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// 停止对话（优雅结束）
  Future<void> stopDialog() async {
    if (!_started) return;
    try {
      await _methodChannel.invokeMethod('stopDialog');
    } catch (e) {
      debugPrint('[VoiceDialog] stopDialog error: $e');
    } finally {
      _started = false;
    }
  }

  /// 打断 AI 当前输出（用户想插话）
  Future<void> interrupt() async {
    if (!_started) return;
    try {
      await _methodChannel.invokeMethod('interrupt');
    } catch (e) {
      debugPrint('[VoiceDialog] interrupt error: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopDialog();
    await _nativeSub?.cancel();
    await _controller.close();
  }

  // ── 内部：监听原生事件 ─────────────────────────────────────────────────────

  void _listenNativeEvents() {
    _nativeSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final map = Map<String, dynamic>.from(raw);
        final event = _parseEvent(map);
        if (event != null) _controller.add(event);
      },
      onError: (Object err) {
        _controller.add(VoiceDialogEvent(
          type: VoiceDialogEventType.error,
          errorMessage: err.toString(),
        ));
      },
    );
  }

  VoiceDialogEvent? _parseEvent(Map<String, dynamic> map) {
    final type = map['type'] as String? ?? '';
    final text = map['text'] as String?;
    final error = map['error'] as String?;

    return switch (type) {
      'connected'    => const VoiceDialogEvent(type: VoiceDialogEventType.connected),
      'userSpeaking' => VoiceDialogEvent(type: VoiceDialogEventType.userSpeaking, text: text),
      'userFinalText'=> VoiceDialogEvent(type: VoiceDialogEventType.userFinalText, text: text),
      'aiSpeaking'   => const VoiceDialogEvent(type: VoiceDialogEventType.aiSpeaking),
      'aiTextDelta'  => VoiceDialogEvent(type: VoiceDialogEventType.aiTextDelta, text: text),
      'aiRoundDone'  => const VoiceDialogEvent(type: VoiceDialogEventType.aiRoundDone),
      'interrupted'  => const VoiceDialogEvent(type: VoiceDialogEventType.interrupted),
      'error'        => VoiceDialogEvent(type: VoiceDialogEventType.error, errorMessage: error),
      'disconnected' => const VoiceDialogEvent(type: VoiceDialogEventType.disconnected),
      _              => null,
    };
  }
}
