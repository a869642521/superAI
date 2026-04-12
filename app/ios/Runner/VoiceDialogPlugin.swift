import Flutter
import Foundation

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接（iOS）
 *
 * ⚠️ 接入前请完成：
 *   1. Podfile 添加: pod 'SpeechEngineToB', '0.0.14.3-bugfix'
 *      执行 pod install
 *   2. 在火山引擎控制台获取 AppId / Access Token
 *   3. 在项目 Runner target → Build Phases → Copy Bundle Resources 添加
 *      AEC 模型文件（SDK 包内提供）
 *   4. 取消本文件中所有 // SDK: 注释行的注释
 */

// SDK: import SpeechEngineToB

class VoiceDialogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // ── 常量 ──────────────────────────────────────────────────────────────────
    static let methodChannelName = "com.starpath/voice_dialog"
    static let eventChannelName  = "com.starpath/voice_dialog_events"

    private static let keyEngineName = "EngineName"
    private static let keyAppId      = "AppId"
    private static let keyAppToken   = "AccessToken"
    private static let keyResourceId = "ResourceId"
    private static let dialogEngine  = "dialog"

    // ── 实例变量 ──────────────────────────────────────────────────────────────
    private var eventSink: FlutterEventSink?

    // SDK: private var engine: SpeechEngine?

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

    // ── MethodChannel 调用处理 ─────────────────────────────────────────────────
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

    // ── SDK 方法实现 ───────────────────────────────────────────────────────────

    private func prepareEnvironment(result: FlutterResult) {
        // SDK: SpeechEngine.prepareEnvironment()
        result(nil)
    }

    private func startDialog(args: [String: Any], result: FlutterResult) {
        guard let appId    = args["appId"]    as? String,
              let appToken = args["appToken"] as? String else {
            result(FlutterError(code: "MISSING_PARAM", message: "appId/appToken required", details: nil))
            return
        }
        let resourceId = args["resourceId"] as? String ?? "volc.speech.dialog"

        // ── TODO: 取消以下注释以启用真实 SDK ──────────────────────────────
        //
        // engine = SpeechEngine()
        // engine?.createEngine(withDelegate: self)
        // engine?.setStringParam(appId,    key: VoiceDialogPlugin.keyAppId)
        // engine?.setStringParam(appToken, key: VoiceDialogPlugin.keyAppToken)
        // engine?.setStringParam(resourceId, key: VoiceDialogPlugin.keyResourceId)
        // engine?.setStringParam(VoiceDialogPlugin.dialogEngine, key: VoiceDialogPlugin.keyEngineName)
        // // AEC 模型路径（Bundle 内的模型文件）
        // if let modelPath = Bundle.main.path(forResource: "aec_model", ofType: nil) {
        //     engine?.setStringParam(modelPath, key: "AECModelPath")
        // }
        // let code = engine?.startEngine() ?? -1
        // guard code == 0 else {
        //     result(FlutterError(code: "START_ERROR", message: "startEngine failed: \(code)", details: nil))
        //     return
        // }
        //
        // ── 无 SDK 时的 Mock（替换为上面的代码后删除）───────────────────────
        pushEvent(["type": "connected"])
        // ──────────────────────────────────────────────────────────────────

        result(true)
    }

    private func stopDialog(result: FlutterResult) {
        // SDK: engine?.stopEngine()
        // SDK: engine = nil
        pushEvent(["type": "disconnected"])
        result(nil)
    }

    private func interrupt(result: FlutterResult) {
        // SDK: engine?.sendEvent("interrupt", params: "{}")
        pushEvent(["type": "interrupted"])
        result(nil)
    }

    // ── 解析 SDK 原始消息 ──────────────────────────────────────────────────────
    private func handleRawMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgType = json["message_type"] as? String else { return }

        switch msgType {
        case "asr.partial_result":
            if let text = (json["result"] as? [String: Any])?["text"] as? String {
                pushEvent(["type": "userSpeaking", "text": text])
            }
        case "asr.final_result":
            if let text = (json["result"] as? [String: Any])?["text"] as? String {
                pushEvent(["type": "userFinalText", "text": text])
            }
        case "tts.playback_started":
            pushEvent(["type": "aiSpeaking"])
        case "llm.text_delta":
            if let delta = json["delta"] as? String {
                pushEvent(["type": "aiTextDelta", "text": delta])
            }
        case "tts.playback_finished":
            pushEvent(["type": "aiRoundDone"])
        case "dialog.interrupt":
            pushEvent(["type": "interrupted"])
        case "error":
            let errMsg = json["message"] as? String ?? "Unknown error"
            pushEvent(["type": "error", "error": errMsg])
        default:
            break
        }
    }

    // ── EventChannel StreamHandler ─────────────────────────────────────────────
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func pushEvent(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

// ── SpeechEngineDelegate 实现（SDK 回调）────────────────────────────────────
// SDK: extension VoiceDialogPlugin: SpeechEngineDelegate {
//     func onRawMessage(_ message: String) {
//         handleRawMessage(message)
//     }
// }

/*
 * ── Podfile 需要添加 ─────────────────────────────────────────────────────────
 *
 * target 'Runner' do
 *   use_frameworks!
 *   pod 'SpeechEngineToB', '0.0.14.3-bugfix'
 *   pod 'SocketRocket',    '0.6.1'
 *   ...
 * end
 *
 * 执行: cd ios && pod install
 */
