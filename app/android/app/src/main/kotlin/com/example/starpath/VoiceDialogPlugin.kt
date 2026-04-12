package com.example.starpath

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接
 *
 * 使用方式：
 *   1. 在 MainActivity.configureFlutterEngine 里调用 VoiceDialogPlugin.register(...)
 *   2. Flutter 侧通过 VoiceDialogBridge 调用
 *
 * ⚠️  接入前请完成：
 *   - build.gradle.kts 添加 SDK 依赖（见末尾注释）
 *   - 在火山引擎控制台获取 AppId / Access Token
 *   - 将 AEC 模型文件放入 assets/aec_model/ 目录（SDK 要求）
 */
class VoiceDialogPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.starpath/voice_dialog"
        private const val EVENT_CHANNEL  = "com.starpath/voice_dialog_events"

        // ── SpeechEngine 参数 Key（与 SDK 头文件一致） ──────────────────────
        private const val KEY_ENGINE_NAME = "EngineName"
        private const val KEY_APP_ID      = "AppId"
        private const val KEY_APP_TOKEN   = "AccessToken"
        private const val KEY_RESOURCE_ID = "ResourceId"
        private const val KEY_LOG_PATH    = "LogFilePath"

        // Dialog 引擎固定名称
        private const val DIALOG_ENGINE   = "dialog"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel  = EventChannel(messenger, EVENT_CHANNEL)

    // EventChannel sink，用于向 Flutter 推送事件
    private var eventSink: EventChannel.EventSink? = null

    // ── SDK 引擎实例（需要 import SDK 后取消注释） ───────────────────────────
    // private var engine: SpeechEngine? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    // ── MethodChannel 调用处理 ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareEnvironment" -> handlePrepareEnvironment(result)
            "startDialog"        -> handleStartDialog(call, result)
            "stopDialog"         -> handleStopDialog(result)
            "interrupt"          -> handleInterrupt(result)
            else -> result.notImplemented()
        }
    }

    private fun handlePrepareEnvironment(result: MethodChannel.Result) {
        try {
            // TODO: 取消注释以启用真实 SDK
            // SpeechEngineGenerator.PrepareEnvironment(context, context.applicationContext as Application)
            result.success(null)
        } catch (e: Exception) {
            result.error("PREPARE_ENV_ERROR", e.message, null)
        }
    }

    private fun handleStartDialog(call: MethodCall, result: MethodChannel.Result) {
        val appId     = call.argument<String>("appId")      ?: return result.error("MISSING_PARAM", "appId required", null)
        val appToken  = call.argument<String>("appToken")   ?: return result.error("MISSING_PARAM", "appToken required", null)
        val resourceId = call.argument<String>("resourceId") ?: "volc.speech.dialog"

        try {
            // ── TODO: 取消以下注释以启用真实 SDK ────────────────────────────
            //
            // val gen = SpeechEngineGenerator.getInstance()
            // engine = gen.createEngine()
            // engine?.apply {
            //     setStringParam(KEY_ENGINE_NAME, DIALOG_ENGINE)
            //     setStringParam(KEY_APP_ID,      appId)
            //     setStringParam(KEY_APP_TOKEN,   appToken)
            //     setStringParam(KEY_RESOURCE_ID, resourceId)
            //     // AEC 回声消除模型路径（从 assets 拷贝到 filesDir）
            //     // setStringParam("AECModelPath", context.filesDir.absolutePath + "/aec_model")
            //     setCallback(object : SpeechEngineCallback {
            //         override fun onRawMessage(message: String) {
            //             handleRawMessage(message)
            //         }
            //     })
            //     startEngine()
            // }
            //
            // ── 以下为无 SDK 的 Mock（删除后替换为上面的代码）───────────────
            pushEvent(mapOf("type" to "connected"))
            // ────────────────────────────────────────────────────────────────

            result.success(true)
        } catch (e: Exception) {
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun handleStopDialog(result: MethodChannel.Result) {
        try {
            // engine?.stopEngine()
            // engine = null
            pushEvent(mapOf("type" to "disconnected"))
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun handleInterrupt(result: MethodChannel.Result) {
        try {
            // engine?.sendEvent("interrupt", "{}")
            pushEvent(mapOf("type" to "interrupted"))
            result.success(null)
        } catch (e: Exception) {
            result.error("INTERRUPT_ERROR", e.message, null)
        }
    }

    // ── 解析 SDK 原始消息（JSON 格式与 OpenAI Realtime 兼容）────────────────

    private fun handleRawMessage(message: String) {
        try {
            val json = JSONObject(message)
            val msgType = json.optString("message_type")

            when (msgType) {
                // 用户语音识别（partial）
                "asr.partial_result" -> {
                    val text = json.optJSONObject("result")?.optString("text") ?: return
                    pushEvent(mapOf("type" to "userSpeaking", "text" to text))
                }
                // 用户语音识别（final）
                "asr.final_result" -> {
                    val text = json.optJSONObject("result")?.optString("text") ?: return
                    pushEvent(mapOf("type" to "userFinalText", "text" to text))
                }
                // AI 开始生成音频（第一帧）
                "tts.playback_started" -> {
                    pushEvent(mapOf("type" to "aiSpeaking"))
                }
                // AI 文本流（streaming）
                "llm.text_delta" -> {
                    val text = json.optString("delta") ?: return
                    pushEvent(mapOf("type" to "aiTextDelta", "text" to text))
                }
                // AI 本轮结束
                "tts.playback_finished" -> {
                    pushEvent(mapOf("type" to "aiRoundDone"))
                }
                // 打断确认
                "dialog.interrupt" -> {
                    pushEvent(mapOf("type" to "interrupted"))
                }
                // 错误
                "error" -> {
                    val errMsg = json.optString("message", "Unknown error")
                    pushEvent(mapOf("type" to "error", "error" to errMsg))
                }
            }
        } catch (e: Exception) {
            pushEvent(mapOf("type" to "error", "error" to (e.message ?: "parse error")))
        }
    }

    // ── EventChannel StreamHandler ────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun pushEvent(data: Map<String, Any?>) {
        // 必须在主线程推送
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(data)
        }
    }

    fun dispose() {
        // engine?.stopEngine()
        // engine = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}

/*
 * ── Android build.gradle.kts 需要添加的依赖 ──────────────────────────────────
 *
 * repositories {
 *     maven { url = uri("https://artifact.bytedance.com/repository/Volcengine/") }
 * }
 *
 * dependencies {
 *     implementation("com.bytedance.speechengine:speechengine_tob:0.0.14.3-bugfix")
 *     implementation("com.squareup.okhttp3:okhttp:4.9.1")
 * }
 */
