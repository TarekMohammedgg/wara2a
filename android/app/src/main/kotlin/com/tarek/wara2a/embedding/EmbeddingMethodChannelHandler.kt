package com.tarek.wara2a.embedding

import android.content.Context
import android.os.Build
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

internal class EmbeddingMethodChannelHandler(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "com.wara2a.ai/embedding"
    }

    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "wara2a-e5-worker").apply { isDaemon = true }
    }.asCoroutineDispatcher()
    private val stateLock = Any()
    private val detached = AtomicBoolean(false)

    @Volatile private var releaseInProgress = false
    @Volatile private var runtime: E5EmbeddingRuntime? = null
    private var activeJob: Job? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call.arguments, result)
            "embed" -> embed(call.arguments, result)
            "cancel" -> cancel(result)
            "unload" -> unload(result)
            "dispose" -> dispose(result)
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
                    runtime?.close()
                    runtime = null
                }
            } finally {
                worker.close()
                scope.cancel()
            }
        }
    }

    private fun initialize(arguments: Any?, result: MethodChannel.Result) {
        if (!isSupportedPlatform()) {
            result.error(
                "unsupported_platform",
                "The offline E5 runtime requires Android API 30+ on arm64-v8a.",
                null,
            )
            return
        }
        val values = arguments as? Map<*, *>
        val modelPath = values?.get("modelPath") as? String
        if (modelPath.isNullOrBlank()) {
            result.error("model_not_installed", "The E5 model path is missing.", null)
            return
        }

        launchExclusive(result) {
            currentCoroutineContext().ensureActive()
            val operation = currentCoroutineContext()[Job]
                ?: error("E5 initialization has no coroutine job")
            val checkpoint = { operation.ensureActive() }
            var created: E5EmbeddingRuntime? = null
            try {
                created = E5EmbeddingRuntime.create(
                    context = applicationContext,
                    modelPath = modelPath,
                    checkpoint = checkpoint,
                )
                checkpoint()
                runtime?.close()
                runtime = created
                created = null
                mapOf(
                    "dimensions" to E5EmbeddingMath.DIMENSIONS,
                    "modelId" to E5EmbeddingMath.MODEL_ID,
                    "runtime" to E5EmbeddingMath.RUNTIME,
                )
            } finally {
                created?.close()
            }
        }
    }

    private fun embed(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val text = values?.get("text") as? String
        if (text.isNullOrBlank()) {
            result.error("invalid_input", "The embedding text is empty.", null)
            return
        }

        launchExclusive(result) {
            val active = runtime
                ?: throw IllegalStateException("The E5 runtime is not initialized.")
            val operation = currentCoroutineContext()[Job]
                ?: error("E5 embed has no coroutine job")
            val checkpoint = { operation.ensureActive() }
            val embedded = active.embed(text, checkpoint = checkpoint)
            if (embedded.dimensions != E5EmbeddingMath.DIMENSIONS ||
                embedded.modelId != E5EmbeddingMath.MODEL_ID ||
                embedded.embedding.size != E5EmbeddingMath.DIMENSIONS
            ) {
                throw IllegalStateException("The E5 runtime returned an incompatible embedding.")
            }
            if (embedded.embedding.any { !it.isFinite() }) {
                throw IllegalStateException("The E5 runtime returned a non-finite embedding.")
            }
            mapOf(
                "embedding" to embedded.embedding,
                "dimensions" to embedded.dimensions,
                "modelId" to embedded.modelId,
                "elapsedMs" to embedded.elapsedMs,
                "tokenCount" to embedded.tokenCount,
                "runtime" to embedded.runtime,
            )
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        cancelActive()
        result.success(null)
    }

    private fun cancelActive() {
        synchronized(stateLock) { activeJob }?.cancel(
            CancellationException("E5 operation cancelled"),
        )
    }

    private fun unload(result: MethodChannel.Result) {
        launchExclusive(result) {
            runtime?.close()
            runtime = null
            null
        }
    }

    private fun dispose(result: MethodChannel.Result) {
        val operation = synchronized(stateLock) {
            if (releaseInProgress) {
                result.error("busy", "The E5 runtime is already releasing resources.", null)
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
                    runtime?.close()
                    runtime = null
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
                result.error("disposed", "The E5 bridge is detached.", null)
                return
            }
            if (releaseInProgress || activeJob?.isActive == true) {
                result.error("busy", "Another E5 operation is already running.", null)
                return
            }
            scope.launch(start = CoroutineStart.LAZY) {
                try {
                    result.success(withContext(worker) { operation() })
                } catch (error: CancellationException) {
                    result.error("cancelled", "The E5 operation was cancelled.", null)
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
        when (error) {
            is CancellationException ->
                result.error("cancelled", "The E5 operation was cancelled.", null)
            is IllegalArgumentException ->
                result.error("invalid_input", error.message, null)
            is IllegalStateException ->
                result.error("initialization_failed", error.message, null)
            else ->
                result.error(
                    "inference_failed",
                    error.message ?: "Local E5 inference failed.",
                    null,
                )
        }
    }

    private fun isSupportedPlatform(): Boolean {
        val hasArm64 = Build.SUPPORTED_ABIS.any { it == "arm64-v8a" }
        return Build.VERSION.SDK_INT >= 30 && hasArm64
    }
}
