---
name: doubao-android-voice-sdk
description: 配置和调试火山引擎豆包端到端实时语音 SDK（SpeechEngineToB）Android 接入。当涉及 VoiceDialogPlugin.kt、豆包语音连接失败、-700 错误、START_ENGINE 指令、麦克风权限、消息回调映射等问题时使用。
---

# 豆包端到端实时语音 Android SDK 接入

## SDK 信息

```
com.bytedance.speechengine:speechengine_tob:0.0.14.5
com.squareup.okhttp3:okhttp:4.9.1
```

Maven 私有源：`https://artifact.bytedance.com/repository/Volcengine/`

## 鉴权参数

| 参数 | 值 | 说明 |
|------|-----|------|
| AppID | `9170285703` | 控制台应用 ID |
| AppToken | `AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa` | 控制台 Access Token |
| AppKey | `PlgvMymc7f3tQnJ6` | 固定值，写死在代码里，非控制台 Secret Key |
| ResourceID | `volc.speech.dialog` | 固定值 |
| DialogAddress | `wss://openspeech.bytedance.com` | 固定值 |
| DialogURI | `/api/v3/realtime/dialogue` | 固定值 |

## ⚠️ 已踩过的坑（必看）

### 坑 1：-700 (ERR_SEND_DIRECTIVE_IN_WRONG_STATE)
**原因**：`setContext()` / `setListener()` 在 `initEngine()` **之后**调用。  
**修复**：必须在 `initEngine()` **之前**调用。

### 坑 2：连接成功但一直"连接中"
**原因**：误用了 `DIRECTIVE_DIALOG_START_CONNECTION`（Dialog 连接层指令），此模式下需要分两步：建连后再发 `DIRECTIVE_DIALOG_START_SESSION`，且 `ENGINE_START` 回调不触发。  
**修复**：使用 `DIRECTIVE_START_ENGINE`（官方文档的正确指令），回调走 `MESSAGE_TYPE_ENGINE_START`。

### 坑 3：连接失败不显示原因
**原因**：`PlatformException` 被 Dart bridge 的 catch 块吃掉，`_volcLastError` 为 null。  
**修复**：在 `VoiceDialogBridge.startDialog()` 里捕获 `PlatformException` 并推送到事件流。

## 正确调用顺序

```kotlin
// 1. 必须在 initEngine 之前
engine.setContext(context.applicationContext)
engine.setListener { type, data, len -> handleMessage(type, data, len) }

// 2. 初始化引擎
engine.initEngine()

// 3. 按官方文档：先 SYNC_STOP，再 START_ENGINE
engine.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
engine.sendDirective(SpeechEngineDefines.DIRECTIVE_START_ENGINE, startPayload)
```

## START_ENGINE Payload 格式

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

- `dialog.extra.model`：O2.0 系列用 `1.2.1.1`，SC2.0 系列用 `2.2.0.0`
- `asr.extra` 和 `tts.audio_config` 不可省略或传 null，必须传空对象 `{}`

## 必填 setOption 参数

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

## 消息回调映射

```kotlin
when (type) {
    MESSAGE_TYPE_ENGINE_START  -> pushEvent("connected")     // 连接+会话就绪
    MESSAGE_TYPE_ENGINE_STOP   -> pushEvent("disconnected")
    MESSAGE_TYPE_ENGINE_ERROR  -> pushEvent("error", data)

    MESSAGE_TYPE_DIALOG_ASR_INFO     -> pushEvent("userSpeaking", text)   // 实时中间结果
    MESSAGE_TYPE_DIALOG_ASR_RESPONSE -> pushEvent("userFinalText", text)  // 最终识别结果
    MESSAGE_TYPE_DIALOG_ASR_ENDED    -> { aiSpeakingEmitted = false }

    MESSAGE_TYPE_DIALOG_CHAT_RESPONSE -> pushEvent("aiTextDelta", content) // LLM 流式
    MESSAGE_TYPE_DIALOG_CHAT_ENDED    -> pushEvent("aiRoundDone")

    MESSAGE_TYPE_DIALOG_TTS_SENTENCE_START -> pushEvent("aiSpeaking")
    MESSAGE_TYPE_DIALOG_TTS_ENDED          -> pushEvent("aiRoundDone")
}
```

ASR_RESPONSE 的 JSON 结构：`{"results":[{"text":"xxx","is_interim":false}]}`  
CHAT_RESPONSE 的文本字段是 `"content"`（不是 `"text"`）。

## 麦克风权限（Android 6+）

AndroidManifest.xml 声明还不够，必须运行时弹窗：

```kotlin
// 在 handleStartDialog 里检查
val hasMic = ContextCompat.checkSelfPermission(context, RECORD_AUDIO) == PERMISSION_GRANTED
if (!hasMic) {
    ActivityCompat.requestPermissions(activity, arrayOf(RECORD_AUDIO), REQUEST_CODE)
    return  // 等权限回调后再继续
}
```

需要在 `MainActivity` 把 `onRequestPermissionsResult` 转发给插件。

## 停止引擎

```kotlin
engine.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
engine.destroyEngine()
```

## Flutter Dart-Define 环境变量

`.env.volc` 中配置，`android.sh` 会通过 `append_env_file` 自动传入：

```
VOLC_VOICE_SDK=true
VOLC_E2E_VOICE=true        # 两个都为 true 才激活端到端模式
VOLC_APP_ID=9170285703
VOLC_APP_TOKEN=AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa
VOLC_DIALOG_MODEL=1.2.1.1
VOLC_TTS_SPEAKER=zh_female_vv_jupiter_bigtts
VOLC_ENABLE_AEC=true       # 真机扬声器开启；戴耳机/模拟器改 false
```

## 相关文件

| 文件 | 说明 |
|------|------|
| `app/android/app/src/main/kotlin/com/example/starpath/VoiceDialogPlugin.kt` | Android 原生桥接插件 |
| `app/android/app/src/main/kotlin/com/example/starpath/MainActivity.kt` | 注册插件 + 转发权限回调 |
| `app/lib/features/voice_dialog/voice_dialog_bridge.dart` | Flutter ↔ 原生 Channel |
| `app/lib/features/chat/presentation/chat_detail_page.dart` | 调用入口 `_initVolcVoice()` |
| `app/.env.volc` | 鉴权环境变量 |
| `app/android.sh` | Android 启动脚本（自动读取 .env.volc） |
| `docs/doubao-voice-dialog-sdk.md` | 完整配置文档 |
