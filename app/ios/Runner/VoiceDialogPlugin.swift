import Flutter
import Foundation
import AVFoundation

#if canImport(SpeechEngineToB)
import SpeechEngineToB

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接（iOS）
 */
class VoiceDialogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let methodChannelName = "com.starpath/voice_dialog"
    static let eventChannelName  = "com.starpath/voice_dialog_events"

    private var eventSink: FlutterEventSink?
    private var engine: SpeechEngine?
    private var sessionStarted = false

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

    /// X-Api-App-Key 为端到端实时语音服务固定值（官方文档 1594356），非控制台 Secret Key
    private static let fixedRealtimeDialogAppKey = "PlgvMymc7f3tQnJ6"

    private func initEngine(appId: String, appToken: String, resourceId: String, result: @escaping FlutterResult) {
        engine = SpeechEngine()
        guard engine?.createEngine(with: self) == true else {
            engine = nil
            result(FlutterError(code: "CREATE_ERROR", message: "createEngineWithDelegate failed", details: nil))
            return
        }

        engine?.setStringParam(SE_DIALOG_ENGINE,                       forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        engine?.setStringParam(appId,                                  forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine?.setStringParam(VoiceDialogPlugin.fixedRealtimeDialogAppKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
        engine?.setStringParam(appToken,                               forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
        engine?.setStringParam(resourceId,                             forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)

        if let modelPath = Bundle.main.path(forResource: "aec_model", ofType: nil) {
            engine?.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)
            engine?.setStringParam(modelPath, forKey: SE_PARAMS_KEY_AEC_MODEL_PATH_STRING)
        }

        let code = engine?.initEngine() ?? SENoError
        guard code == SENoError else {
            engine?.destroy()
            engine = nil
            result(FlutterError(code: "INIT_ERROR", message: "initEngine returned \(code.rawValue)", details: nil))
            return
        }

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

extension VoiceDialogPlugin: SpeechEngineDelegate {

    func onMessage(with type: SEMessageType, andData data: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }

        switch type {
        case SEEventConnectionStarted:
            engine?.send(SEDirectiveEventStartSession)
            sessionStarted = true
            pushEvent(["type": "connected"])

        case SEEventConnectionFailed:
            let err = json["message"] as? String ?? "Connection failed"
            pushEvent(["type": "error", "error": err])

        case SEEventConnectionFinished:
            pushEvent(["type": "disconnected"])

        case SEEventASRInfo:
            let text = json["text"] as? String ?? ""
            if !text.isEmpty {
                pushEvent(["type": "userSpeaking", "text": text])
            }

        case SEEventASRResponse:
            let text = json["text"] as? String ?? ""
            if !text.isEmpty {
                pushEvent(["type": "userFinalText", "text": text])
            }

        case SEEventASREnded:
            break

        case SEEventChatResponse:
            if let delta = json["text"] as? String, !delta.isEmpty {
                pushEvent(["type": "aiTextDelta", "text": delta])
            }

        case SEEventChatEnded:
            break

        case SEEventTTSSentenceStart:
            pushEvent(["type": "aiSpeaking"])

        case SEEventTTSSentenceEnd:
            break

        case SEEventTTSEnded:
            pushEvent(["type": "aiRoundDone"])

        case SEEventSessionStarted:
            break

        case SEEventSessionFinished:
            pushEvent(["type": "aiRoundDone"])

        case SEEventSessionFailed:
            let err = json["message"] as? String ?? "Session failed"
            pushEvent(["type": "error", "error": err])

        case SEEventSessionCanceled:
            break

        case SEEngineError:
            let err = json["message"] as? String ?? "Unknown engine error"
            pushEvent(["type": "error", "error": err])

        default:
            break
        }
    }
}

#else

/// 未链接 SpeechEngineToB 时（例如模拟器 Pod 跳过）的占位实现。
class VoiceDialogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let methodChannelName = "com.starpath/voice_dialog"
    static let eventChannelName  = "com.starpath/voice_dialog_events"

    private var eventSink: FlutterEventSink?

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

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareEnvironment":
            result(nil)
        case "startDialog":
            result(FlutterError(
                code: "NO_NATIVE_SDK",
                message: "火山语音 SDK 未集成（模拟器开发模式）。真机请删除 ios/.skip_volc_for_sim 后执行 pod install。",
                details: nil
            ))
        case "stopDialog", "interrupt":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

#endif
