package com.example.starpath

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var voiceDialogPlugin: VoiceDialogPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        voiceDialogPlugin = VoiceDialogPlugin(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onDestroy() {
        voiceDialogPlugin?.dispose()
        voiceDialogPlugin = null
        super.onDestroy()
    }
}
