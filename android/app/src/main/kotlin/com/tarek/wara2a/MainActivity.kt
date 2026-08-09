package com.tarek.wara2a

import com.tarek.wara2a.ocr.OcrMethodChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ocrHandler: OcrMethodChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ocrHandler = OcrMethodChannelHandler(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ocrHandler?.detach()
        ocrHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
