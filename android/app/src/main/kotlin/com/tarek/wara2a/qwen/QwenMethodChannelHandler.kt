package com.tarek.wara2a.qwen

import android.content.Context
import android.os.Build
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.system.measureNanoTime
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

internal class QwenMethodChannelHandler(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "com.wara2a.ai/qwen"
        private const val MAX_CONTEXT_TOKENS = 1280
        private const val RUNTIME_VERSION = "tasks-genai:0.10.27"
        private const val MODEL_ID =
            "litert-community/Qwen2.5-0.5B-Instruct@6c237a59-q8-task"
    }

    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "wara2a-qwen-worker").apply { isDaemon = true }
    }.asCoroutineDispatcher()
    private val stateLock = Any()
    private val detached = AtomicBoolean(false)

    @Volatile private var releaseInProgress = false
    @Volatile private var engine: LlmInference? = null
    @Volatile private var activeSession: LlmInferenceSession? = null
    private var activeJob: Job? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capability" -> result.success(capability())
            "initialize" -> initialize(call.arguments, result)
            "interpret" -> interpret(call.arguments, result)
            "cancel" -> cancel(result)
            "dispose" -> release(result)
            else -> result.notImplemented()
        }
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        if (!detached.compareAndSet(false, true)) return
        cancelActive()
        val operation = synchronized(stateLock) { activeJob }
        scope.launch {
            try {
                if (operation != null) joinAll(operation)
                withContext(worker) {
                    activeSession?.close()
                    activeSession = null
                    engine?.close()
                    engine = null
                }
            } finally {
                worker.close()
                scope.cancel()
            }
        }
    }

    private fun capability(): Map<String, Any?> {
        val hasArm64 = Build.SUPPORTED_ABIS.any { it == "arm64-v8a" }
        return if (Build.VERSION.SDK_INT < 26 || !hasArm64) {
            mapOf(
                "status" to "unsupportedPlatform",
                "runtime" to "MediaPipe LLM Inference",
                "platform" to "android",
                "runtimeVersion" to RUNTIME_VERSION,
                "reason" to "Qwen inference currently requires Android 8.0+ on arm64-v8a.",
                "supportedFormats" to listOf("task"),
            )
        } else {
            mapOf(
                "status" to "available",
                "runtime" to "MediaPipe LLM Inference (maintenance-only)",
                "platform" to "android",
                "runtimeVersion" to RUNTIME_VERSION,
                "reason" to "The pinned local CPU runtime supports the verified Qwen .task artifact.",
                "supportedFormats" to listOf("task"),
            )
        }
    }

    private fun initialize(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val modelPath = values?.get("modelPath") as? String
        if (modelPath.isNullOrBlank()) {
            result.error("model_not_installed", "The Qwen model path is missing.", null)
            return
        }
        val modelFile = File(modelPath)
        if (!modelFile.isFile || modelFile.extension.lowercase() != "task") {
            result.error(
                "model_not_installed",
                "The verified Qwen .task model is not installed.",
                null,
            )
            return
        }

        launchExclusive(result) {
            currentCoroutineContext().ensureActive()
            var created: LlmInference? = null
            try {
                val options = LlmInference.LlmInferenceOptions.builder()
                    .setModelPath(modelFile.absolutePath)
                    .setMaxTokens(MAX_CONTEXT_TOKENS)
                    .setMaxTopK(1)
                    .setPreferredBackend(LlmInference.Backend.CPU)
                    .build()
                created = LlmInference.createFromOptions(applicationContext, options)
                currentCoroutineContext().ensureActive()
                engine?.close()
                engine = created
                created = null
                mapOf("modelId" to MODEL_ID)
            } finally {
                created?.close()
            }
        }
    }

    private fun interpret(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val prompt = values?.get("prompt") as? String
        val maximumOutputTokens = (values?.get("maximumOutputTokens") as? Number)?.toInt()
        if (prompt.isNullOrBlank()) {
            result.error("invalid_runtime_response", "The Qwen prompt is empty.", null)
            return
        }
        if (maximumOutputTokens == null || maximumOutputTokens !in 64..512) {
            result.error("invalid_runtime_response", "The output-token limit is invalid.", null)
            return
        }

        launchExclusive(result) {
            val activeEngine = engine
                ?: throw IllegalStateException("The Qwen runtime is not initialized.")
            val options = LlmInferenceSession.LlmInferenceSessionOptions.builder()
                .setTopK(1)
                .setTopP(1.0f)
                .setTemperature(0.0f)
                .setRandomSeed(0)
                .build()
            val session = LlmInferenceSession.createFromOptions(activeEngine, options)
            activeSession = session
            try {
                val inputTokens = session.sizeInTokens(prompt)
                if (inputTokens + maximumOutputTokens > MAX_CONTEXT_TOKENS) {
                    throw PromptTooLongException(inputTokens, maximumOutputTokens)
                }
                session.addQueryChunk(prompt)
                var responseText = ""
                val elapsedNanos = measureNanoTime {
                    val accumulator = StrictJsonObjectAccumulator()
                    val future = session.generateResponseAsync { partial, done ->
                        val complete = accumulator.add(partial)
                        if (complete != null && !done) {
                            try {
                                session.cancelGenerateResponseAsync()
                            } catch (_: Throwable) {
                                // The completed object is already captured. A late
                                // cancellation failure cannot add text to it.
                            }
                        }
                    }
                    var finalResponse: String? = null
                    try {
                        finalResponse = future.get()
                    } catch (error: CancellationException) {
                        if (accumulator.completeJson == null) throw error
                    } catch (error: ExecutionException) {
                        if (accumulator.completeJson == null) throw error
                    }
                    responseText = accumulator.completeJson
                        ?: StrictJsonObjectAccumulator.extract(finalResponse.orEmpty())
                        ?: finalResponse.orEmpty()
                }
                currentCoroutineContext().ensureActive()
                if (responseText.isBlank()) {
                    throw IllegalStateException("Qwen returned an empty response.")
                }
                mapOf(
                    "text" to responseText.trim(),
                    "modelId" to MODEL_ID,
                    "inputTokens" to inputTokens,
                    "elapsedMs" to elapsedNanos / 1_000_000L,
                )
            } finally {
                activeSession = null
                session.close()
            }
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        cancelActive()
        result.success(null)
    }

    private fun cancelActive() {
        try {
            activeSession?.cancelGenerateResponseAsync()
        } catch (_: Throwable) {
            // The coroutine cancellation below still suppresses a late result.
        }
        synchronized(stateLock) { activeJob }?.cancel(
            kotlinx.coroutines.CancellationException("Qwen operation cancelled"),
        )
    }

    private fun release(result: MethodChannel.Result) {
        val operation = synchronized(stateLock) {
            if (releaseInProgress) {
                result.error("busy", "The Qwen runtime is already releasing resources.", null)
                return
            }
            releaseInProgress = true
            activeJob
        }
        cancelActive()
        scope.launch {
            try {
                if (operation != null) joinAll(operation)
                withContext(worker) {
                    activeSession?.close()
                    activeSession = null
                    engine?.close()
                    engine = null
                }
                result.success(null)
            } catch (error: Throwable) {
                reportError(result, error)
            } finally {
                releaseInProgress = false
            }
        }
    }

    private fun launchExclusive(
        result: MethodChannel.Result,
        operation: suspend () -> Any?,
    ) {
        val job = synchronized(stateLock) {
            if (detached.get()) {
                result.error("disposed", "The Qwen bridge is detached.", null)
                return
            }
            if (releaseInProgress || activeJob?.isActive == true) {
                result.error("busy", "Another Qwen operation is already running.", null)
                return
            }
            scope.launch(start = CoroutineStart.LAZY) {
                try {
                    result.success(withContext(worker) { operation() })
                } catch (error: kotlinx.coroutines.CancellationException) {
                    result.error("cancelled", "The Qwen operation was cancelled.", null)
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

    private fun reportError(result: MethodChannel.Result, error: Throwable) {
        val cause = if (error is ExecutionException) error.cause ?: error else error
        when (cause) {
            is CancellationException,
            is kotlinx.coroutines.CancellationException ->
                result.error("cancelled", "The Qwen operation was cancelled.", null)
            is PromptTooLongException ->
                result.error("prompt_too_long", cause.message, null)
            is IllegalStateException ->
                result.error("initialization_failed", cause.message, null)
            else -> result.error("inference_failed", "Local Qwen inference failed.", null)
        }
    }

    private class PromptTooLongException(
        inputTokens: Int,
        outputTokens: Int,
    ) : IllegalArgumentException(
        "The OCR prompt uses $inputTokens tokens and cannot reserve $outputTokens output tokens in the 1280-token artifact.",
    )
}
