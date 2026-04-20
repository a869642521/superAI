---
name: doubao-voice-sdk
description: 配置和调试火山引擎豆包端到端实时语音 SDK（SpeechEngineToB），Android + iOS 双平台接入。当涉及 VoiceDialogPlugin.kt / VoiceDialogPlugin.swift、AppDelegate prepareEnvironment、-700 / kAFAssistantErrorDomain 1101 / ENGINE_ERROR、START_ENGINE 指令、麦克风权限、AVAudioSession 冲突、speech_to_text 并存、消息回调映射、dart-define 传值失败等问题时使用。
---

# 豆包端到端实时语音 SDK 接入（Android + iOS）

本仓 Flutter App 通过原生桥接把火山引擎豆包端到端实时语音（`SpeechEngineToB`，资源 ID `volc.speech.dialog`）接进 Android 和 iOS 真机。两端要做到**体验一致的实时语音对话**（流式 ASR partial + LLM 流式字幕 + 流式 TTS），关键在于**严格对齐官方推荐的 `StartEngine` 一步启动模式**，并规避本仓已经踩过的所有坑。

## 1. 通用配置（两端共享）

### 1.1 鉴权与接入点

| 参数 | 值 | 说明 |
|------|-----|------|
| AppID | `9170285703` | 控制台应用 ID，可改 |
| AppToken | `AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa` | 控制台 Access Token，可改 |
| AppKey | `PlgvMymc7f3tQnJ6` | **固定值**，是端到端实时语音服务的 `X-Api-App-Key`，**不是控制台 Secret Key**，两端都硬编码 |
| ResourceID | `volc.speech.dialog` | 固定值 |
| DialogAddress | `wss://openspeech.bytedance.com` | 固定值，**两端都必须显式 setOption** |
| DialogURI | `/api/v3/realtime/dialogue` | 固定值，**两端都必须显式 setOption** |

### 1.2 `.env.volc`（dart-define 源）

```
VOLC_VOICE_SDK=true
VOLC_E2E_VOICE=true         # 两个都为 true 才激活端到端模式
VOLC_APP_ID=9170285703
VOLC_APP_TOKEN=AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa
VOLC_DIALOG_MODEL=1.2.1.1   # O2.0→1.2.1.1，SC2.0→2.2.0.0
VOLC_TTS_SPEAKER=zh_female_vv_jupiter_bigtts
VOLC_ENABLE_AEC=true        # 真机扬声器开启；戴耳机/模拟器改 false
```

### 1.3 `StartEngine` Payload（两端一字不差）

```json
{
  "dialog": {
    "bot_name": "豆包",
    "extra": { "model": "1.2.1.1" }
  },
  "asr": { "extra": {} },
  "tts": {
    "audio_config": {},
    "speaker": "zh_female_vv_jupiter_bigtts"
  }
}
```

- `dialog.extra.model`：O2.0 → `1.2.1.1`；SC2.0 → `2.2.0.0`
- `asr.extra` 和 `tts.audio_config` **不可省略或传 null**，必须传空对象 `{}`

### 1.4 事件语义（Flutter 侧统一）

Flutter 只认这几种事件类型，两端原生必须按相同语义映射：

| 事件 | 语义 |
|---|---|
| `connected` | 引擎启动完成，可以开始说话 |
| `userSpeaking` | 用户说话 partial |
| `userFinalText` | 用户说话整句 final |
| `aiSpeaking` | AI 开始说话（首个 LLM delta 或 TTS 首句） |
| `aiTextDelta` | AI 文本流式增量 |
| `aiRoundDone` | AI 本轮说完 |
| `interrupted` | 用户打断 AI |
| `error` | 引擎错误 |
| `disconnected` | 引擎停止 |

---

## 2. Android 侧（`VoiceDialogPlugin.kt`）

### 2.1 SDK 依赖

```gradle
implementation "com.bytedance.speechengine:speechengine_tob:0.0.14.5"
implementation "com.squareup.okhttp3:okhttp:4.9.1"
```

Maven 私有源：`https://artifact.bytedance.com/repository/Volcengine/`

### 2.2 必填参数

```kotlin
engine.setOptionString(PARAMS_KEY_ENGINE_NAME_STRING, DIALOG_ENGINE)
engine.setOptionString(PARAMS_KEY_APP_ID_STRING,      appId)
engine.setOptionString(PARAMS_KEY_APP_KEY_STRING,     "PlgvMymc7f3tQnJ6")  // 固定值
engine.setOptionString(PARAMS_KEY_APP_TOKEN_STRING,   appToken)
engine.setOptionString(PARAMS_KEY_RESOURCE_ID_STRING, "volc.speech.dialog")
engine.setOptionString(PARAMS_KEY_UID_STRING,         "starpath-user")
engine.setOptionString(PARAMS_KEY_DIALOG_ADDRESS_STRING, "wss://openspeech.bytedance.com")
engine.setOptionString(PARAMS_KEY_DIALOG_URI_STRING,     "/api/v3/realtime/dialogue")
```

### 2.3 正确调用顺序（顺序错了就 -700）

```kotlin
// 1) setContext / setListener 必须在 initEngine 之前，否则早期回调丢失
engine.setContext(context.applicationContext)
engine.setListener { type, data, len -> handleMessage(type, data, len) }

// 2) 初始化
engine.initEngine()

// 3) 按官方文档：先 SYNC_STOP，再 START_ENGINE(payload)
engine.sendDirective(DIRECTIVE_SYNC_STOP_ENGINE, "")
engine.sendDirective(DIRECTIVE_START_ENGINE, startPayload)
```

### 2.4 消息回调映射

```kotlin
when (type) {
    MESSAGE_TYPE_ENGINE_START  -> pushEvent("connected")     // 连接+会话就绪
    MESSAGE_TYPE_ENGINE_STOP   -> pushEvent("disconnected")
    MESSAGE_TYPE_ENGINE_ERROR  -> pushEvent("error", data)

    MESSAGE_TYPE_DIALOG_ASR_INFO     -> pushEvent("userSpeaking", text)
    MESSAGE_TYPE_DIALOG_ASR_RESPONSE -> pushEvent("userFinalText", text)
    MESSAGE_TYPE_DIALOG_ASR_ENDED    -> { aiSpeakingEmitted = false }

    MESSAGE_TYPE_DIALOG_CHAT_RESPONSE -> pushEvent("aiTextDelta", content)
    MESSAGE_TYPE_DIALOG_CHAT_ENDED    -> pushEvent("aiRoundDone")

    MESSAGE_TYPE_DIALOG_TTS_SENTENCE_START -> pushEvent("aiSpeaking")
    MESSAGE_TYPE_DIALOG_TTS_ENDED          -> pushEvent("aiRoundDone")
}
```

- `ASR_RESPONSE` 的 JSON：`{"results":[{"text":"xxx","is_interim":false}]}`
- `CHAT_RESPONSE` 的文本字段是 **`"content"`**（不是 `"text"`）

### 2.5 麦克风权限（Android 6+）

AndroidManifest 声明不够，必须运行时请求：

```kotlin
val hasMic = ContextCompat.checkSelfPermission(context, RECORD_AUDIO) == PERMISSION_GRANTED
if (!hasMic) {
    ActivityCompat.requestPermissions(activity, arrayOf(RECORD_AUDIO), REQUEST_CODE)
    return  // 等权限回调后再继续
}
```

记得在 `MainActivity.onRequestPermissionsResult` 里把结果转发给插件。

### 2.6 停止

```kotlin
engine.sendDirective(DIRECTIVE_SYNC_STOP_ENGINE, "")
engine.destroyEngine()
```

---

## 3. iOS 侧（`VoiceDialogPlugin.swift` + `AppDelegate.swift`）

### 3.1 Podfile

```ruby
source 'https://github.com/volcengine/volcengine-specs.git'
source 'https://cdn.cocoapods.org/'

platform :ios, '13.0'

# 本仓用 0.0.14.5；官方文档最小版本为 0.0.14.3-bugfix。0.0.14 之后无需 TTNet
pod 'SpeechEngineToB', '0.0.14.5'
pod 'SocketRocket',    '0.6.1'
```

模拟器不能链接真机静态库（`.a`），本仓通过 `ios/.skip_volc_for_sim` 标记文件区分：
- 模拟器：`touch ios/.skip_volc_for_sim && pod install`
- 真机：`rm -f ios/.skip_volc_for_sim && pod install`

Swift 代码用 `#if canImport(SpeechEngineToB)` 分叉，模拟器侧走占位实现（`startDialog` 直接报 `NO_NATIVE_SDK`），Dart 侧 iOS 上**绝不回退 `speech_to_text`**（见坑 5）。

### 3.2 `AppDelegate` 里只调一次 `prepareEnvironment`

```swift
#if canImport(SpeechEngineToB)
import SpeechEngineToB
#endif

override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    #if canImport(SpeechEngineToB)
    _ = SpeechEngine.prepareEnvironment()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

**`prepareEnvironment` 是类方法，整个 App 生命周期只调一次。** 在 `startDialog` 里反复调会浪费时间且有概率导致状态异常。

### 3.3 `AVAudioSession` 必须显式配置（不然外放/蓝牙都会翻车）

```swift
try session.setCategory(.playAndRecord, mode: .voiceChat,
    options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
try session.setActive(true, options: [])
```

### 3.4 必填参数

```swift
engine?.setStringParam(SE_DIALOG_ENGINE,      forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
engine?.setStringParam(appId,                 forKey: SE_PARAMS_KEY_APP_ID_STRING)
engine?.setStringParam("PlgvMymc7f3tQnJ6",    forKey: SE_PARAMS_KEY_APP_KEY_STRING)  // 固定值
engine?.setStringParam(appToken,              forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
engine?.setStringParam("volc.speech.dialog",  forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
engine?.setStringParam("starpath-user",       forKey: SE_PARAMS_KEY_UID_STRING)
engine?.setStringParam("wss://openspeech.bytedance.com", forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
engine?.setStringParam("/api/v3/realtime/dialogue",       forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)
engine?.setBoolParam(true, forKey: SE_PARAMS_KEY_ASR_SHOW_UTTER_BOOL)  // 流式 partial
```

### 3.5 启动顺序（和 Android 一致，**不要用 StartConnection/StartSession 两步）**

```swift
_ = engine?.createEngine(with: self)   // delegate
// ... setStringParam / setBoolParam ...
let code = engine?.initEngine()
guard code == SENoError else { /* return error */ }

_ = engine?.send(SEDirectiveSyncStopEngine)
let startRet = engine?.send(SEDirectiveStartEngine, data: buildStartEnginePayload())
```

Swift 侧 `sendDirective:` / `sendDirective:data:` 被 Swift 导入器自动重命名为 `send(_:)` / `send(_:data:)`。

### 3.6 回调类型（使用新的 `SEEvent*` 常量，不要用被标 deprecated 的 `SEDialog*`）

```swift
switch type {
case SEEngineStart:   pushEvent(["type": "connected"])
case SEEngineStop:    pushEvent(["type": "disconnected"])
case SEEngineError:   pushEvent(["type": "error", "error": err])

case SEEventASRInfo:      pushEvent(["type": "userSpeaking", "text": extractAsrText(json)])
case SEEventASRResponse:  pushEvent(["type": "userFinalText", "text": extractAsrText(json)])
case SEEventASREnded:     aiSpeakingEmitted = false

case SEEventChatResponse:
    let delta = extractChatDelta(json)  // 字段名 content / text / delta 都要兼容
    if !delta.isEmpty {
        if !aiSpeakingEmitted { aiSpeakingEmitted = true; pushEvent(["type": "aiSpeaking"]) }
        pushEvent(["type": "aiTextDelta", "text": delta])
    }
case SEEventChatEnded:    aiSpeakingEmitted = false

case SEEventTTSSentenceStart:
    if !aiSpeakingEmitted { aiSpeakingEmitted = true; pushEvent(["type": "aiSpeaking"]) }
case SEEventTTSEnded:     pushEvent(["type": "aiRoundDone"]); aiSpeakingEmitted = false

default: NSLog("[VoiceDialog] unhandled msg type=\(type.rawValue)")  // 出意外类型必打日志
}
```

### 3.7 停止

```swift
_ = engine?.send(SEDirectiveSyncStopEngine)
engine?.destroy()   // Swift 导入器把 destroyEngine 重命名为 destroy()
engine = nil
```

### 3.8 签名 / Bundle ID

真机构建需要 Apple Developer Team ID。本仓方案：
- Bundle ID：`com.starpath.app`（或你的 Team 下可用的值）
- 通过 `ios/Local.xcconfig`（git 忽略）注入 `DEVELOPMENT_TEAM` 避免命令行报 "Signing for 'Runner' requires a development team"

### 3.9 Xcconfig 小坑

CocoaPods 会对 Profile 构建抱怨 "base configuration ... not set"。修复：
- 新建 `app/ios/Flutter/Profile.xcconfig`：
  ```
  #include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"
  #include "Generated.xcconfig"
  ```
- 在 `Runner.xcodeproj/project.pbxproj` 里把 Runner target 的 Profile 配置的 `baseConfigurationReference` 改为这个新文件。

---

## 4. Flutter 侧共用（`chat_detail_page.dart` + `voice_dialog_bridge.dart`）

### 4.1 启动判定

```dart
static const bool _useVolcSdk =
    bool.fromEnvironment('VOLC_VOICE_SDK', defaultValue: false) &&
    bool.fromEnvironment('VOLC_E2E_VOICE', defaultValue: false);
```

两个 dart-define 同时为 true 才激活端到端模式。

### 4.2 **iOS 上严禁 fallback 到 `speech_to_text`**

```dart
Future<void> _initVolcVoice() async {
  final bool allowSttFallback = !Platform.isIOS;

  if (_volcAppId.isEmpty || _volcAppToken.isEmpty) {
    if (allowSttFallback) { await _initStt(); await _initTts(); }
    else { _volcLastError = '未读到 VOLC_APP_ID / VOLC_APP_TOKEN'; }
    return;
  }
  // ... startDialog ...
  if (!ok) {
    _volcConnected = false;
    _volcLastError ??= 'startDialog 返回 false（看 Xcode 控制台 [VoiceDialog] 日志）';
    if (allowSttFallback) { await _initStt(); await _initTts(); }
  }
}
```

**原因**：iOS 上 `speech_to_text` 依赖 `SFSpeechRecognizer`，与 `SpeechEngineToB` 抢 `AVAudioSession`，会产生 `kAFAssistantErrorDomain Code=1101` 且表现为"只能语音播报、不实时"。Android 上保留 fallback 不受影响。

### 4.3 `VoiceDialogBridge.startDialog` 必须 **把 PlatformException 转成 error 事件**

```dart
try {
  final result = await _methodChannel.invokeMethod<bool>('startDialog', {...});
  return result == true;
} on PlatformException catch (e) {
  _controller.add(VoiceDialogEvent(
    type: VoiceDialogEventType.error,
    errorMessage: '${e.code}: ${e.message}',
  ));
  return false;
}
```

不加的话 Dart 侧只看到 `false`，UI 显示"语音服务连接失败，请检查网络与 API Key"这种通用文案，无法定位。

---

## 5. 启动脚本

### 5.1 Android

`app/android.sh`：内部 `source .env.volc` 并通过 `--dart-define=KEY=VALUE` 传给 `flutter run`。

### 5.2 iOS

`app/ios-device.sh`：
- **不能用** `source <(grep -v '^\s*#' ...)` —— **macOS 的 BSD `grep` 不支持 `\s`**，会把变量吃掉导致 dart-define 传空值。
- 必须用 `while IFS='=' read -r k v` 逐行解析，然后去除 `\r` 和前后空白。
- 读完后**强校验** `VOLC_APP_ID` / `VOLC_APP_TOKEN` 非空，读不到直接 `exit 1`。
- 启动前 echo 所有 dart-define（token 做脱敏），确保能看到实际传入了什么。

---

## 6. 已踩过的坑总表（出现症状按这里查）

### 坑 1 · Android：-700 (`ERR_SEND_DIRECTIVE_IN_WRONG_STATE`)
**原因**：`setContext()` / `setListener()` 在 `initEngine()` 之后调用。
**修复**：必须在 `initEngine()` **之前**调。

### 坑 2 · Android：连接成功但一直"连接中"
**原因**：误用了 `DIRECTIVE_DIALOG_START_CONNECTION`（Dialog 层指令），`ENGINE_START` 不触发。
**修复**：使用 `DIRECTIVE_START_ENGINE`（引擎层），回调走 `MESSAGE_TYPE_ENGINE_START`。

### 坑 3 · iOS：安卓实时、iOS 只是"语音播报"
**原因 A**：`StartSession` 没带 payload，SDK 走默认 model → 非流式链路。
**原因 B**：`Platform.isIOS` 时 Volc 失败后 fallback 启了 `speech_to_text` → 实际走的是 STT→LLM→TTS 文本链路。
**修复**：改用 `StartEngine(payload)` 一步到位；iOS 禁用 STT fallback。

### 坑 4 · iOS：`-[SFSpeechRecognitionTask ...] Error Domain=kAFAssistantErrorDomain Code=1101`
**原因**：`speech_to_text` 与 `SpeechEngineToB` 同时运行，抢 `AVAudioSession`。
**修复**：见坑 3 原因 B。根治 = iOS 路径完全不启 `speech_to_text`。

### 坑 5 · iOS：UI 提示"语音服务连接失败，请检查网络与 API Key"
**原因**：dart-define 没传进来，`_volcAppId.isEmpty`。
**根因**：`ios-device.sh` 老版本用 `source <(grep -v '^\s*#' ...)`，macOS BSD grep 不识别 `\r\s`。
**修复**：用 `while read` 逐行解析 + `require VOLC_APP_ID` 硬校验。

### 坑 6 · iOS：`Stale file ... is located outside of the allowed root paths`
**原因**：Flutter 老 build 产物里 `xxx_privacy.bundle` 位置不合法，Xcode 15+ User Script Sandboxing 拒绝。
**修复**：`flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/.symlinks build && rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* && pod install`。

### 坑 7 · iOS：CocoaPods 警告 "did not set the base configuration of your project"
**原因**：Flutter 模板没生成 `Profile.xcconfig`，Profile config 复用了 `Release.xcconfig`，CocoaPods 无法注入 `Pods-Runner.profile.xcconfig`。
**修复**：新建 `app/ios/Flutter/Profile.xcconfig`，在 `project.pbxproj` 里把 Profile 的 `baseConfigurationReference` 指向它。

### 坑 8 · iOS：连接失败不显示原因
**原因**：`PlatformException` 被 Dart bridge catch 吃掉，`_volcLastError` 为 null。
**修复**：`VoiceDialogBridge` 里捕获后必须推一条 `error` 事件到 stream。

### 坑 9 · 两端：`prepareEnvironment` 被调多次
**iOS**：`SpeechEngine.prepareEnvironment()` 是类方法，App 生命周期只调一次 → 放 AppDelegate。
**Android**：类似处理，放 Application.onCreate 更好（本仓目前在首次 startDialog 前调，也 OK）。

### 坑 10 · 两端：TTS 刚开始就被 `aiSpeaking` 事件刷两次
**原因**：`CHAT_RESPONSE` 先到 → 发 `aiSpeaking`；紧跟着 `TTS_SENTENCE_START` 又发一次。
**修复**：维护一个 `aiSpeakingEmitted` 状态位，同一轮只发一次。`ASR_ENDED` / `CHAT_ENDED` / `TTS_ENDED` 时重置。

---

## 7. 问题排查检查清单

### Android
1. Xcode—不对，logcat 里过滤 `VoiceDialogPlugin`。
2. 看是否到 `START_ENGINE returned 0`。不是 0 就按错误码查 `SpeechEngineDefines.ERR_*`。
3. `MESSAGE_TYPE_ENGINE_START` 有没有进 → 没进就是连接没起来，看 token / 网关可达性。
4. `AndroidManifest.xml` 是否有 `RECORD_AUDIO`、`INTERNET`。

### iOS
1. Xcode Debug Area 过滤 `[VoiceDialog]`，按顺序应看到：
   ```
   [VoiceDialog] SpeechEngine.prepareEnvironment = 1
   [VoiceDialog] initEngine appId=xxxx*** ...
   [VoiceDialog] initEngine OK
   [VoiceDialog] StartEngine payload={...}
   [VoiceDialog] ENGINE_START
   ```
   缺哪一条，就到对应环节查。
2. `unhandled msg type=N len=M` 要贴出来，可能是新 SDK 版本加了事件类型。
3. 拔线后想看日志：打开 `Console.app` → 选择 iPhone → 过滤 `VoiceDialog`。

### Flutter Dart
1. `flutter: [VolcVoice] 缺少 VOLC_APP_ID 或 VOLC_APP_TOKEN` → dart-define 没传进来，查启动脚本。
2. `flutter: [VolcVoice] startDialog failed` → 看下一条 error 事件，或 Xcode 控制台。
3. UI 显示通用"语音服务连接失败" → `_volcLastError` 为空，说明 bridge 没捕获 `PlatformException`，回头查 `voice_dialog_bridge.dart`。

---

## 8. 工作流

### 新增功能 / 改动时
1. **仅 Android 改动** → 只动 `VoiceDialogPlugin.kt` + `android.sh`。
2. **仅 iOS 改动** → 只动 `VoiceDialogPlugin.swift` + `AppDelegate.swift` + `ios-device.sh`。
3. **跨平台 Dart 改动** → 动 `chat_detail_page.dart` / `voice_dialog_bridge.dart` 时，**必须用 `Platform.isIOS` / `Platform.isAndroid` 隔离平台相关分支**，不要让 iOS 的规避策略影响 Android 既有流程。

### 本地验证
```bash
# Android 真机
cd app && ./android.sh

# iOS 真机
cd app && ./ios-device.sh

# iOS 模拟器（语音 SDK 会被跳过，走 STT+TTS 链路）
cd app && touch ios/.skip_volc_for_sim && cd ios && pod install && cd .. && flutter run
```

### 发版
- Android：`flutter build apk --release --dart-define=...` 或 `aab`
- iOS：`flutter build ipa --release --dart-define=...`

两端 **`--dart-define` 都必须带上 `.env.volc` 里的那些 KEY**，否则烧进包里的凭证是空的。

---

## 9. 相关文件速查

| 平台 | 文件 | 作用 |
|---|---|---|
| Android | `app/android/app/src/main/kotlin/com/example/starpath/VoiceDialogPlugin.kt` | 原生桥接插件 |
| Android | `app/android/app/src/main/kotlin/com/example/starpath/MainActivity.kt` | 注册插件 + 转发权限回调 |
| Android | `app/android.sh` | Android 启动脚本 |
| iOS | `app/ios/Runner/VoiceDialogPlugin.swift` | 原生桥接插件（`#if canImport(SpeechEngineToB)` 分叉） |
| iOS | `app/ios/Runner/AppDelegate.swift` | `SpeechEngine.prepareEnvironment()` 调用点 |
| iOS | `app/ios/Podfile` | 依赖声明（含真机 / 模拟器分支） |
| iOS | `app/ios/Flutter/Profile.xcconfig` | 修复 Profile 配置警告 |
| iOS | `app/ios-device.sh` | iOS 真机启动脚本（读 `.env.volc` → dart-define） |
| 共用 | `app/lib/features/voice_dialog/voice_dialog_bridge.dart` | Flutter ↔ 原生 Channel |
| 共用 | `app/lib/features/chat/presentation/chat_detail_page.dart` | 调用入口 `_initVolcVoice()` |
| 共用 | `app/.env.volc` | 鉴权环境变量（**不要提交到 git**） |
| 文档 | `docs/doubao-voice-dialog-sdk.md` | 完整配置文档（可选） |
