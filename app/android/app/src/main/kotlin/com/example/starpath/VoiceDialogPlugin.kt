package com.example.starpath

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// 火山引擎 SpeechEngine SDK（依赖在 build.gradle.kts 中启用）
import com.bytedance.speech.speechengine.SpeechEngine
import com.bytedance.speech.speechengine.SpeechEngineDefines
import com.bytedance.speech.speechengine.SpeechEngineGenerator

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接（Android）
 *
 * API 基于官方文档 https://www.volcengine.com/docs/6561/1597643 实现：
 *  - SpeechEngineGenerator.PrepareEnvironment(context, application)
 *  - engine = SpeechEngineGenerator.getInstance(); engine.createEngine()
 *  - engine.setOptionString / setOptionBoolean / setOptionInt
 *  - engine.initEngine()  ->  engine.setContext / setListener
 *  - engine.sendDirective(DIRECTIVE_START_ENGINE, json)  启动
 *  - engine.sendDirective(DIRECTIVE_SYNC_STOP_ENGINE, "")  停止
 *  - engine.destroyEngine()
 *  - 消息回调接口: onSpeechMessage(type: Int, data: ByteArray, len: Int)
 */
class VoiceDialogPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.starpath/voice_dialog"
        private const val EVENT_CHANNEL  = "com.starpath/voice_dialog_events"

        // Dialog 服务地址（官方文档固定值）
        private const val DIALOG_ADDRESS = "wss://openspeech.bytedance.com"
        private const val DIALOG_URI     = "/api/v3/realtime/dialogue"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel  = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var engine: SpeechEngine? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    // ── MethodChannel ─────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareEnvironment" -> handlePrepareEnvironment(result)
            "startDialog"        -> handleStartDialog(call, result)
            "stopDialog"         -> handleStopDialog(result)
            "interrupt"          -> handleInterrupt(result)
            else                 -> result.notImplemented()
        }
    }

    private fun handlePrepareEnvironment(result: MethodChannel.Result) {
        try {
            SpeechEngineGenerator.PrepareEnvironment(
                context,
                context.applicationContext as android.app.Application,
            )
            result.success(null)
        } catch (e: Exception) {
            result.error("PREPARE_ENV_ERROR", e.message, null)
        }
    }

    private fun handleStartDialog(call: MethodCall, result: MethodChannel.Result) {
        val appId      = call.argument<String>("appId")      ?: return result.error("MISSING_PARAM", "appId required", null)
        val appToken   = call.argument<String>("appToken")   ?: return result.error("MISSING_PARAM", "appToken required", null)
        val resourceId = call.argument<String>("resourceId") ?: SpeechEngineDefines.PARAMS_KEY_RESOURCE_ID_STRING

        try {
            // 创建引擎实例（官方文档：getInstance() 获取生成器，createEngine() 创建实例）
            engine = SpeechEngineGenerator.getInstance()
            engine!!.createEngine()

            // 必填参数
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_ENGINE_NAME_STRING, SpeechEngineDefines.DIALOG_ENGINE)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_ID_STRING,      appId)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_TOKEN_STRING,   appToken)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_RESOURCE_ID_STRING, resourceId)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_DIALOG_ADDRESS_STRING, DIALOG_ADDRESS)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_DIALOG_URI_STRING,  DIALOG_URI)
            // UID 用于线上定位问题（用固定字符串即可）
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_UID_STRING, "starpath-user")

            // AEC 回声消除（将 SDK 包内 aec.model 文件放到 assets/aec/aec.model）
            val aecPath = copyAecModelToFilesDir()
            if (aecPath != null) {
                engine!!.setOptionBoolean(SpeechEngineDefines.PARAMS_KEY_ENABLE_AEC_BOOL, true)
                engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_AEC_MODEL_PATH_STRING, aecPath)
            }

            // 初始化引擎
            val ret = engine!!.initEngine()
            if (ret != SpeechEngineDefines.ERR_NO_ERROR) {
                engine!!.destroyEngine()
                engine = null
                return result.error("INIT_ERROR", "initEngine returned $ret", null)
            }

            // 设置 context 和消息监听
            engine!!.setContext(context.applicationContext)
            engine!!.setListener { type, data, len ->
                handleSpeechMessage(type, data, len)
            }

            // 启动引擎（建立 WebSocket 连接并开始对话）
            val startRet = engine!!.sendDirective(
                SpeechEngineDefines.DIRECTIVE_START_ENGINE,
                "{\"dialog\":{\"bot_name\":\"豆包\"}}",
            )
            if (startRet != SpeechEngineDefines.ERR_NO_ERROR) {
                engine!!.destroyEngine()
                engine = null
                return result.error("START_ERROR", "sendDirective(DIRECTIVE_START_ENGINE) returned $startRet", null)
            }

            pushEvent(mapOf("type" to "connected"))
            result.success(true)

        } catch (e: Exception) {
            engine?.destroyEngine()
            engine = null
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun handleStopDialog(result: MethodChannel.Result) {
        try {
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
            engine?.destroyEngine()
            engine = null
            pushEvent(mapOf("type" to "disconnected"))
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun handleInterrupt(result: MethodChannel.Result) {
        try {
            // 打断当前 AI 输出（文档中对应 ClientInterrupt 指令）
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_EVENT_CLIENT_INTERRUPT, "")
            pushEvent(mapOf("type" to "interrupted"))
            result.success(null)
        } catch (e: Exception) {
            result.error("INTERRUPT_ERROR", e.message, null)
        }
    }

    // ── 消息回调处理 ───────────────────────────────────────────────────────────

    private fun handleSpeechMessage(type: Int, data: ByteArray, len: Int) {
        val strData = String(data, 0, len, Charsets.UTF_8)
        when (type) {
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_START  -> {
                // 引擎启动成功（已在 startDialog 里推送 connected）
            }
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_STOP   -> {
                pushEvent(mapOf("type" to "disconnected"))
            }
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_ERROR  -> {
                pushEvent(mapOf("type" to "error", "error" to strData))
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_INFO     -> {
                // 用户开始说话 / 实时识别中间结果
                val text = parseJsonField(strData, "text") ?: ""
                if (text.isNotEmpty()) {
                    pushEvent(mapOf("type" to "userSpeaking", "text" to text))
                }
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_RESPONSE -> {
                // 最终 ASR 识别结果
                val text = parseJsonField(strData, "text") ?: ""
                if (text.isNotEmpty()) {
                    pushEvent(mapOf("type" to "userFinalText", "text" to text))
                }
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_ENDED    -> {
                // ASR 结束，等待 LLM 回复
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_CHAT_RESPONSE -> {
                // LLM 文本流式回调
                val text = parseJsonField(strData, "text") ?: strData
                if (text.isNotEmpty()) {
                    pushEvent(mapOf("type" to "aiTextDelta", "text" to text))
                }
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_CHAT_ENDED   -> {
                // LLM 回复结束（TTS 播放也随后结束）
                pushEvent(mapOf("type" to "aiRoundDone"))
            }
            // TTS 相关（不同版本常量名可能不同，用数值做兜底）
            // MESSAGE_TYPE_DIALOG_TTS_SENTENCE_START = 3008
            3008 -> pushEvent(mapOf("type" to "aiSpeaking"))
            // MESSAGE_TYPE_DIALOG_TTS_ENDED = 3011
            3011 -> pushEvent(mapOf("type" to "aiRoundDone"))
        }
    }

    // ── 工具函数 ───────────────────────────────────────────────────────────────

    /**
     * 将 assets/aec/aec.model 拷贝到内部存储，返回完整文件路径（含文件名）。
     * AEC 模型是单个文件，非目录。
     */
    private fun copyAecModelToFilesDir(): String? {
        return try {
            val destFile = context.filesDir.resolve("aec/aec.model")
            if (!destFile.exists()) {
                destFile.parentFile?.mkdirs()
                context.assets.open("aec/aec.model").use { input ->
                    destFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }
            destFile.absolutePath
        } catch (_: Exception) {
            null // 没有 AEC 模型时不影响基础对话，跳过
        }
    }

    /** 简单提取 JSON 字符串字段，避免额外依赖 */
    private fun parseJsonField(json: String, key: String): String? {
        return try {
            val org = org.json.JSONObject(json)
            if (org.has(key)) org.optString(key).takeIf { it.isNotEmpty() } else null
        } catch (_: Exception) {
            null
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
        mainHandler.post { eventSink?.success(data) }
    }

    fun dispose() {
        try {
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
            engine?.destroyEngine()
        } catch (_: Exception) {}
        engine = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
