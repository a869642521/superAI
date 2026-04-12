import Flutter
import Foundation
import AVFoundation

// 火山引擎 iOS SDK（pod install 后自动可用）
import SpeechEngineToB

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接（iOS）
 *
 * API 基于 SpeechEngineToB 0.0.14.5 头文件实现，主要接口：
 *   - SpeechEngine.prepareEnvironment()
 *   - SpeechEngine().createEngineWithDelegate(self)
 *   - engine.setStringParam / setBoolParam / setIntParam
 *   - engine.initEngine()  （注意：不是 startEngine）
 *   - engine.sendDirective(SEDirective)
 *   - delegate: onMessageWithType(_:andData:)
 */
class VoiceDialogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let methodChannelName = "com.starpath/voice_dialog"
    static let eventChannelName  = "com.starpath/voice_dialog_events"

    private var eventSink: FlutterEventSink?
    private var engine: SpeechEngine?
    private var sessionStarted = false

    // ── 注册 ──────────────────────────────────────────────────────────────────
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VoiceDialogPlugin()

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    // ── MethodChannel ─────────────────────────────────────────────────────────
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareEnvironment":
            prepareEnvironment(result: result)
        case "startDialog":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "MISSING_ARGS", message: "args required", details: nil))
                return
            }
            startDialog(args: args, result: result)
        case "stopDialog":
            stopDialog(result: result)
        case "interrupt":
            interrupt(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── SDK 实现 ──────────────────────────────────────────────────────────────

    private func prepareEnvironment(result: FlutterResult) {
        SpeechEngine.prepareEnvironment()
        result(nil)
    }

    private func startDialog(args: [String: Any], result: @escaping FlutterResult) {
        guard let appId    = args["appId"]    as? String,
              let appToken = args["appToken"] as? String else {
            result(FlutterError(code: "MISSING_PARAM", message: "appId/appToken required", details: nil))
            return
        }
        let resourceId = args["resourceId"] as? String ?? "volc.speech.dialog"

        // 请求麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MIC_DENIED", message: "Microphone permission denied", details: nil))
                }
                return
            }
            DispatchQueue.main.async {
                self.initEngine(appId: appId, appToken: appToken, resourceId: resourceId, result: result)
            }
        }
    }

    private func initEngine(appId: String, appToken: String, resourceId: String, result: @escaping FlutterResult) {
        engine = SpeechEngine()
        guard engine?.createEngine(with: self) == true else {
            engine = nil
            result(FlutterError(code: "CREATE_ERROR", message: "createEngineWithDelegate failed", details: nil))
            return
        }

        // 必填参数
        engine?.setStringParam(SE_DIALOG_ENGINE,  forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        engine?.setStringParam(appId,             forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine?.setStringParam(appToken,          forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
        engine?.setStringParam(resourceId,        forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)

        // AEC 回声消除（将 SDK 中的 aec_model 文件添加到 Xcode Copy Bundle Resources）
        if let modelPath = Bundle.main.path(forResource: "aec_model", ofType: nil) {
            engine?.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)
            engine?.setStringParam(modelPath, forKey: SE_PARAMS_KEY_AEC_MODEL_PATH_STRING)
        }

        // initEngine 返回 0 表示成功
        let code = engine?.initEngine() ?? SENoError
        guard code == SENoError else {
            engine?.destroy()
            engine = nil
            result(FlutterError(code: "INIT_ERROR", message: "initEngine returned \(code.rawValue)", details: nil))
            return
        }

        // 建立 WebSocket 连接
        engine?.send(SEDirectiveEventStartConnection)
        result(true)
    }

    private func stopDialog(result: FlutterResult) {
        if sessionStarted {
            engine?.send(SEDirectiveEventCancelSession)
            sessionStarted = false
        }
        engine?.send(SEDirectiveEventFinishConnection)
        engine?.destroy()
        engine = nil
        pushEvent(["type": "disconnected"])
        result(nil)
    }

    private func interrupt(result: FlutterResult) {
        engine?.send(SEDirectiveEventClientInterrupt)
        pushEvent(["type": "interrupted"])
        result(nil)
    }

    // ── EventChannel StreamHandler ────────────────────────────────────────────
    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func pushEvent(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.eventSink?(data) }
    }
}

// ── SpeechEngineDelegate（SDK 原始消息回调）──────────────────────────────────
extension VoiceDialogPlugin: SpeechEngineDelegate {

    func onMessage(with type: SEMessageType, andData data: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }

        switch type {
        // 连接事件
        case SEEventConnectionStarted:
            // 连接成功后自动开启会话
            engine?.send(SEDirectiveEventStartSession)
            sessionStarted = true
            pushEvent(["type": "connected"])

        case SEEventConnectionFailed:
            let err = json["message"] as? String ?? "Connection failed"
            pushEvent(["type": "error", "error": err])

        case SEEventConnectionFinished:
            pushEvent(["type": "disconnected"])

        // ASR（语音识别）
        case SEEventASRInfo:
            // 实时部分结果
            let text = json["text"] as? String ?? ""
            if !text.isEmpty {
                pushEvent(["type": "userSpeaking", "text": text])
            }

        case SEEventASRResponse:
            // 最终识别结果
            let text = json["text"] as? String ?? ""
            if !text.isEmpty {
                pushEvent(["type": "userFinalText", "text": text])
            }

        case SEEventASREnded:
            break // ASR 结束，无需额外事件

        // LLM（大模型文本流）
        case SEEventChatResponse:
            if let delta = json["text"] as? String, !delta.isEmpty {
                pushEvent(["type": "aiTextDelta", "text": delta])
            }

        case SEEventChatEnded:
            break // TTS 结束时一并发 aiRoundDone

        // TTS（语音合成播放）
        case SEEventTTSSentenceStart:
            pushEvent(["type": "aiSpeaking"])

        case SEEventTTSSentenceEnd:
            break

        case SEEventTTSEnded:
            pushEvent(["type": "aiRoundDone"])

        // 会话事件
        case SEEventSessionStarted:
            break

        case SEEventSessionFinished:
            pushEvent(["type": "aiRoundDone"])

        case SEEventSessionFailed:
            let err = json["message"] as? String ?? "Session failed"
            pushEvent(["type": "error", "error": err])

        case SEEventSessionCanceled:
            break

        // 错误
        case SEEngineError:
            let err = json["message"] as? String ?? "Unknown engine error"
            pushEvent(["type": "error", "error": err])

        default:
            break
        }
    }
}
