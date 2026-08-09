package com.tarek.wara2a.ocr

import android.os.Build
import com.paddle.ocr.OcrModelFiles
import com.paddle.ocr.OcrRunResult
import com.paddle.ocr.PaddleOcrException
import com.paddle.ocr.PaddleOcrRuntime
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class OcrMethodChannelHandler(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "com.wara2a.ai/ocr"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "wara2a-ocr-worker").apply { isDaemon = true }
    }.asCoroutineDispatcher()
    private val stateLock = Any()
    private val shutdownStarted = AtomicBoolean(false)

    @Volatile private var disposed = false
    private var activeJob: Job? = null
    private var runtime: PaddleOcrRuntime? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capability" -> result.success(capability())
            "initialize" -> initialize(call.arguments, result)
            "recognizeInvoice" -> recognizeInvoice(call.arguments, result)
            "cancel" -> cancel(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        shutdown(null)
    }

    private fun capability(): Map<String, Any?> {
        val hasArm64 = Build.SUPPORTED_ABIS.any { it == "arm64-v8a" }
        return if (Build.VERSION.SDK_INT < 26 || !hasArm64) {
            mapOf(
                "status" to "unsupportedPlatform",
                "runtime" to "PaddleOCR PP-OCRv5 / ONNX Runtime",
                "platform" to "android",
                "runtimeVersion" to PaddleOcrRuntime.RUNTIME_DESCRIPTION,
                "reason" to "The verified OCR runtime currently requires Android 8.0+ on arm64-v8a.",
                "supportedFormats" to listOf("onnx", "yml", "yaml"),
            )
        } else {
            mapOf(
                "status" to "available",
                "runtime" to "PaddleOCR PP-OCRv5 / ONNX Runtime",
                "platform" to "android",
                "runtimeVersion" to PaddleOcrRuntime.RUNTIME_DESCRIPTION,
                "reason" to "The local CPU runtime is available; verified external model files are required before initialization.",
                "supportedFormats" to listOf("onnx", "yml", "yaml"),
            )
        }
    }

    private fun initialize(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *> ?: run {
            result.error("initialization_failed", "OCR model arguments are missing.", null)
            return
        }
        val files = try {
            OcrModelFiles(
                detectorModelPath = values.requiredString("detectorModelPath"),
                detectorConfigPath = values.requiredString("detectorConfigPath"),
                arabicModelPath = values.requiredString("arabicModelPath"),
                arabicConfigPath = values.requiredString("arabicConfigPath"),
                latinModelPath = values.requiredString("latinModelPath"),
                latinConfigPath = values.requiredString("latinConfigPath"),
            )
        } catch (error: IllegalArgumentException) {
            result.error("model_not_installed", error.message, null)
            return
        }

        launchExclusive(result) {
            val operation = currentCoroutineContext()[Job]
                ?: error("OCR initialization has no coroutine job")
            val checkpoint = { operation.ensureActive() }
            var created: PaddleOcrRuntime? = null
            try {
                created = PaddleOcrRuntime.create(files, numThreads = 4, checkpoint = checkpoint)
                checkpoint()
                runtime?.close()
                runtime = created
                created = null
                null
            } finally {
                created?.close()
            }
        }
    }

    private fun recognizeInvoice(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val imagePath = values?.get("imagePath") as? String
        if (imagePath.isNullOrBlank()) {
            result.error("invalid_image", "The invoice image path is missing.", null)
            return
        }
        launchExclusive(result) {
            val operation = currentCoroutineContext()[Job]
                ?: error("OCR recognition has no coroutine job")
            val checkpoint = { operation.ensureActive() }
            val activeRuntime = runtime
                ?: throw PaddleOcrException.ModelNotInstalled("OCR models are not initialized")
            checkpoint()
            val bitmap = InvoiceImageDecoder.decode(imagePath)
            try {
                checkpoint()
                activeRuntime.recognize(bitmap, checkpoint).toChannelMap()
            } finally {
                bitmap.recycle()
            }
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        val job = synchronized(stateLock) { activeJob }
        job?.cancel(CancellationException("OCR operation cancelled"))
        result.success(null)
    }

    private fun dispose(result: MethodChannel.Result) {
        shutdown(result)
    }

    private fun launchExclusive(
        result: MethodChannel.Result,
        operation: suspend () -> Any?,
    ) {
        val job = synchronized(stateLock) {
            if (disposed) {
                result.error("disposed", "The OCR runtime is disposed.", null)
                return
            }
            if (activeJob?.isActive == true) {
                result.error("busy", "Another OCR operation is already running.", null)
                return
            }
            scope.launch(start = CoroutineStart.LAZY) {
                try {
                    val value = withContext(worker) { operation() }
                    result.success(value)
                } catch (error: CancellationException) {
                    result.error("cancelled", "The OCR operation was cancelled.", null)
                } catch (error: Throwable) {
                    reportError(result, error)
                } finally {
                    val completedJob = currentCoroutineContext()[Job]
                    synchronized(stateLock) {
                        if (activeJob === completedJob) activeJob = null
                    }
                }
            }.also { activeJob = it }
        }
        job.start()
    }

    private fun shutdown(result: MethodChannel.Result?) {
        if (!shutdownStarted.compareAndSet(false, true)) {
            result?.success(null)
            return
        }
        val operation = synchronized(stateLock) {
            disposed = true
            activeJob?.also { it.cancel(CancellationException("OCR runtime disposed")) }
        }
        scope.launch {
            try {
                if (operation != null) joinAll(operation)
                withContext(worker) {
                    runtime?.close()
                    runtime = null
                }
                result?.success(null)
            } catch (error: Throwable) {
                if (result != null) reportError(result, error)
            } finally {
                worker.close()
                scope.cancel()
            }
        }
    }

    private fun reportError(result: MethodChannel.Result, error: Throwable) {
        when (error) {
            is PaddleOcrException.ModelNotInstalled ->
                result.error("model_not_installed", error.message, null)
            is PaddleOcrException.IncompatibleArtifact,
            is PaddleOcrException.InitializationFailed ->
                result.error("initialization_failed", error.message, null)
            is PaddleOcrException.InvalidImage ->
                result.error("invalid_image", error.message, null)
            else -> result.error("inference_failed", "The local OCR runtime failed.", null)
        }
    }

    private fun Map<*, *>.requiredString(key: String): String =
        (get(key) as? String)?.takeIf(String::isNotBlank)
            ?: throw IllegalArgumentException("Missing $key model path")

    private fun OcrRunResult.toChannelMap(): Map<String, Any?> = mapOf(
        "imageWidth" to imageWidth,
        "imageHeight" to imageHeight,
        "runtime" to PaddleOcrRuntime.RUNTIME_DESCRIPTION,
        "lines" to lines.mapIndexed { order, line ->
            mapOf(
                "order" to order,
                "text" to line.text,
                "box" to line.box.points.map { point ->
                    mapOf("x" to point.x.toDouble(), "y" to point.y.toDouble())
                },
                "script" to line.script.wireName,
                "confidence" to line.confidence.toDouble(),
                "recognizer" to line.recognizer,
            )
        },
        "timings" to mapOf(
            "detectionMs" to timings.detectionMs,
            "arabicRecognitionMs" to timings.arabicRecognitionMs,
            "latinRecognitionMs" to timings.latinRecognitionMs,
            "totalMs" to timings.totalMs,
        ),
    )
}
