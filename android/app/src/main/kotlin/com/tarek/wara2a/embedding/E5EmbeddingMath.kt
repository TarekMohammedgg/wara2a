package com.tarek.wara2a.embedding

import kotlin.math.sqrt

/** Pure helpers for the multilingual-E5 Android bridge. */
internal object E5EmbeddingMath {
    const val DIMENSIONS = 384
    const val MAXIMUM_SEQUENCE_TOKENS = 512
    const val MODEL_ID = "intfloat-multilingual-e5-small-qint8-614241f"
    const val RUNTIME =
        "ONNX Runtime Android 1.21.1 + ONNX Runtime Extensions Android 0.13.0"
    const val TOKENIZER_ASSET = "embedding/multilingual_e5_small_tokenizer.onnx"

    /**
     * Truncate token IDs to [maxTokens] while preserving a trailing EOS when
     * the untruncated sequence is longer than the limit.
     */
    fun truncateTokenIds(
        tokenIds: LongArray,
        maxTokens: Int = MAXIMUM_SEQUENCE_TOKENS,
    ): LongArray {
        require(maxTokens > 1) { "maxTokens must be greater than 1." }
        if (tokenIds.isEmpty()) {
            throw IllegalArgumentException("Tokenizer returned no token IDs.")
        }
        if (tokenIds.size <= maxTokens) return tokenIds.copyOf()
        val truncated = LongArray(maxTokens)
        System.arraycopy(tokenIds, 0, truncated, 0, maxTokens - 1)
        truncated[maxTokens - 1] = tokenIds.last()
        return truncated
    }

    /**
     * Attention-mask mean pool over `[sequence, hidden]` then L2-normalize.
     * Returns a finite 384-d unit vector or throws.
     */
    fun meanPoolAndL2Normalize(
        hiddenStates: FloatArray,
        sequenceLength: Int,
        dimensions: Int = DIMENSIONS,
        attentionMask: FloatArray? = null,
    ): FloatArray {
        if (sequenceLength <= 0) {
            throw IllegalArgumentException("Sequence length must be positive.")
        }
        if (dimensions != DIMENSIONS) {
            throw IllegalArgumentException("Expected $DIMENSIONS dimensions.")
        }
        if (hiddenStates.size != sequenceLength * dimensions) {
            throw IllegalArgumentException(
                "Hidden-state size ${hiddenStates.size} does not match " +
                    "sequenceLength=$sequenceLength dimensions=$dimensions.",
            )
        }
        val mask = attentionMask ?: FloatArray(sequenceLength) { 1f }
        if (mask.size != sequenceLength) {
            throw IllegalArgumentException("Attention mask length mismatch.")
        }

        val pooled = FloatArray(dimensions)
        var kept = 0f
        for (token in 0 until sequenceLength) {
            val weight = mask[token]
            if (weight <= 0f) continue
            kept += weight
            val offset = token * dimensions
            for (dim in 0 until dimensions) {
                pooled[dim] += hiddenStates[offset + dim] * weight
            }
        }
        if (kept <= 0f) {
            throw IllegalArgumentException("Attention mask kept zero tokens.")
        }
        for (dim in 0 until dimensions) {
            pooled[dim] /= kept
        }

        var sumSquares = 0.0
        for (value in pooled) {
            if (!value.isFinite()) {
                throw IllegalArgumentException("Embedding contains a non-finite value.")
            }
            sumSquares += value.toDouble() * value.toDouble()
        }
        val norm = sqrt(sumSquares)
        if (!norm.isFinite() || norm <= 1e-12) {
            throw IllegalArgumentException("Embedding L2 norm is not usable.")
        }
        for (dim in 0 until dimensions) {
            pooled[dim] = (pooled[dim] / norm).toFloat()
            if (!pooled[dim].isFinite()) {
                throw IllegalArgumentException("Normalized embedding is non-finite.")
            }
        }
        return pooled
    }
}
