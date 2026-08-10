package com.tarek.wara2a

import com.tarek.wara2a.embedding.EmbeddingMethodChannelHandler
import com.tarek.wara2a.models.ModelStorageMethodChannelHandler
import com.tarek.wara2a.ocr.OcrMethodChannelHandler
import com.tarek.wara2a.qwen.QwenMethodChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ocrHandler: OcrMethodChannelHandler? = null
    private var modelStorageHandler: ModelStorageMethodChannelHandler? = null
    private var qwenHandler: QwenMethodChannelHandler? = null
    private var embeddingHandler: EmbeddingMethodChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ocrHandler = OcrMethodChannelHandler(flutterEngine.dartExecutor.binaryMessenger)
        modelStorageHandler = ModelStorageMethodChannelHandler(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        qwenHandler = QwenMethodChannelHandler(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        embeddingHandler = EmbeddingMethodChannelHandler(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ocrHandler?.detach()
        ocrHandler = null
        modelStorageHandler?.detach()
        modelStorageHandler = null
        qwenHandler?.detach()
        qwenHandler = null
        embeddingHandler?.detach()
        embeddingHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
