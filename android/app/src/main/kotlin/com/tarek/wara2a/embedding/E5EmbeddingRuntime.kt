package com.tarek.wara2a.embedding

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.extensions.OrtxPackage
import android.content.Context
import java.io.Closeable
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer
import kotlin.system.measureNanoTime

/**
 * Offline multilingual-E5 encoder:
 * ORT Extensions SentencePiece tokenizer graph -> encoder ONNX ->
 * attention-mask mean pool -> L2 normalize.
 */
internal class E5EmbeddingRuntime private constructor(
    private val environment: OrtEnvironment,
    private val tokenizerSession: OrtSession,
    private val encoderSession: OrtSession,
    private val encoderInputIdsName: String,
    private val encoderAttentionMaskName: String?,
    private val encoderTokenTypeIdsName: String?,
    private val encoderOutputName: String,
) : Closeable {
    @Volatile private var closed = false

    fun embed(text: String, checkpoint: () -> Unit = {}): EmbeddingResult {
        ensureOpen()
        val trimmed = text.trim()
        if (trimmed.isEmpty()) {
            throw IllegalArgumentException("Embedding input must not be empty.")
        }

        var tokenCount = 0
        var vector = FloatArray(0)
        val elapsedNanos = measureNanoTime {
            checkpoint()
            val tokenIds = tokenize(trimmed)
            checkpoint()
            val truncated = E5EmbeddingMath.truncateTokenIds(tokenIds)
            tokenCount = truncated.size
            checkpoint()
            val hidden = encode(truncated)
            checkpoint()
            vector = E5EmbeddingMath.meanPoolAndL2Normalize(
                hiddenStates = hidden,
                sequenceLength = truncated.size,
            )
        }
        return EmbeddingResult(
            embedding = vector.map { it.toDouble() },
            dimensions = E5EmbeddingMath.DIMENSIONS,
            modelId = E5EmbeddingMath.MODEL_ID,
            tokenCount = tokenCount,
            elapsedMs = elapsedNanos / 1_000_000L,
            runtime = E5EmbeddingMath.RUNTIME,
        )
    }

    private fun tokenize(text: String): LongArray {
        val inputs = HashMap<String, OnnxTensor>(1)
        val outputs: OrtSession.Result
        try {
            inputs["inputs"] = OnnxTensor.createTensor(
                environment,
                arrayOf(text),
            )
            outputs = tokenizerSession.run(inputs)
        } finally {
            inputs.values.forEach { runCatching { it.close() } }
        }
        outputs.use { result ->
            val tokensTensor = result.get(0) as? OnnxTensor
                ?: throw IllegalStateException("Tokenizer did not return token IDs.")
            val buffer = tokensTensor.longBuffer
                ?: throw IllegalStateException("Tokenizer token buffer is unavailable.")
            val tokens = LongArray(buffer.remaining())
            buffer.get(tokens)
            if (tokens.isEmpty()) {
                throw IllegalStateException("Tokenizer returned an empty token sequence.")
            }
            return tokens
        }
    }

    private fun encode(tokenIds: LongArray): FloatArray {
        val sequenceLength = tokenIds.size.toLong()
        val shape = longArrayOf(1L, sequenceLength)
        val attention = LongArray(tokenIds.size) { 1L }
        val tokenTypes = LongArray(tokenIds.size)
        val inputs = HashMap<String, OnnxTensor>(3)
        val outputs: OrtSession.Result
        try {
            inputs[encoderInputIdsName] = OnnxTensor.createTensor(
                environment,
                LongBuffer.wrap(tokenIds),
                shape,
            )
            if (encoderAttentionMaskName != null) {
                inputs[encoderAttentionMaskName] = OnnxTensor.createTensor(
                    environment,
                    LongBuffer.wrap(attention),
                    shape,
                )
            }
            if (encoderTokenTypeIdsName != null) {
                inputs[encoderTokenTypeIdsName] = OnnxTensor.createTensor(
                    environment,
                    LongBuffer.wrap(tokenTypes),
                    shape,
                )
            }
            outputs = encoderSession.run(inputs)
        } finally {
            inputs.values.forEach { runCatching { it.close() } }
        }
        outputs.use { result ->
            val output = result.get(encoderOutputName)
                .orElseThrow { IllegalStateException("Encoder did not return hidden states.") }
                as? OnnxTensor
                ?: throw IllegalStateException("Encoder output is not a tensor.")
            val info = output.info
            val dims = info.shape
            if (dims.size != 3 || dims[0] != 1L || dims[2] != E5EmbeddingMath.DIMENSIONS.toLong()) {
                throw IllegalStateException(
                    "Unexpected encoder output shape: ${dims.contentToString()}",
                )
            }
            if (dims[1] != sequenceLength) {
                throw IllegalStateException(
                    "Encoder sequence length ${dims[1]} != token count $sequenceLength.",
                )
            }
            val buffer: FloatBuffer = output.floatBuffer
                ?: throw IllegalStateException("Encoder output buffer is unavailable.")
            val values = FloatArray(buffer.remaining())
            buffer.get(values)
            return values
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        runCatching { tokenizerSession.close() }
        runCatching { encoderSession.close() }
    }

    private fun ensureOpen() {
        if (closed) throw IllegalStateException("The E5 runtime is closed.")
    }

    data class EmbeddingResult(
        val embedding: List<Double>,
        val dimensions: Int,
        val modelId: String,
        val tokenCount: Int,
        val elapsedMs: Long,
        val runtime: String,
    )

    companion object {
        fun create(
            context: Context,
            modelPath: String,
            checkpoint: () -> Unit = {},
        ): E5EmbeddingRuntime {
            val modelFile = File(modelPath)
            if (!modelFile.isFile) {
                throw IllegalArgumentException("The verified E5 ONNX model is not installed.")
            }
            if (modelFile.length() <= 0L) {
                throw IllegalArgumentException("The E5 ONNX model file is empty.")
            }

            val environment = OrtEnvironment.getEnvironment()
            checkpoint()
            val tokenizerBytes = context.assets.open(E5EmbeddingMath.TOKENIZER_ASSET).use { stream ->
                stream.readBytes()
            }
            if (tokenizerBytes.isEmpty()) {
                throw IllegalStateException("The bundled E5 tokenizer asset is empty.")
            }
            checkpoint()

            var tokenizerOptions: OrtSession.SessionOptions? = null
            var encoderOptions: OrtSession.SessionOptions? = null
            var tokenizerSession: OrtSession? = null
            var encoderSession: OrtSession? = null
            try {
                tokenizerOptions = OrtSession.SessionOptions().apply {
                    setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                    setIntraOpNumThreads(2)
                    registerCustomOpLibrary(OrtxPackage.getLibraryPath())
                }
                checkpoint()
                tokenizerSession = environment.createSession(tokenizerBytes, tokenizerOptions)
                checkpoint()

                encoderOptions = OrtSession.SessionOptions().apply {
                    setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                    setIntraOpNumThreads(4)
                }
                encoderSession = environment.createSession(modelFile.absolutePath, encoderOptions)
                checkpoint()

                val inputNames = encoderSession.inputNames
                val inputIdsName = resolveInputName(
                    inputNames,
                    preferred = listOf("input_ids", "inputs"),
                    label = "input_ids",
                )
                val attentionMaskName = inputNames.firstOrNull { name ->
                    name.equals("attention_mask", ignoreCase = true)
                }
                val tokenTypeIdsName = inputNames.firstOrNull { name ->
                    name.equals("token_type_ids", ignoreCase = true)
                }
                val outputName = encoderSession.outputNames.firstOrNull()
                    ?: throw IllegalStateException("The E5 encoder has no outputs.")

                val created = E5EmbeddingRuntime(
                    environment = environment,
                    tokenizerSession = tokenizerSession,
                    encoderSession = encoderSession,
                    encoderInputIdsName = inputIdsName,
                    encoderAttentionMaskName = attentionMaskName,
                    encoderTokenTypeIdsName = tokenTypeIdsName,
                    encoderOutputName = outputName,
                )
                tokenizerSession = null
                encoderSession = null
                return created
            } catch (error: Throwable) {
                runCatching { tokenizerSession?.close() }
                runCatching { encoderSession?.close() }
                throw error
            } finally {
                runCatching { tokenizerOptions?.close() }
                runCatching { encoderOptions?.close() }
            }
        }

        private fun resolveInputName(
            names: Set<String>,
            preferred: List<String>,
            label: String,
        ): String {
            for (candidate in preferred) {
                names.firstOrNull { it.equals(candidate, ignoreCase = true) }?.let { return it }
            }
            return names.firstOrNull()
                ?: throw IllegalStateException("The E5 encoder has no $label input.")
        }
    }
}
