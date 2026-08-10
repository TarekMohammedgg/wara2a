package com.tarek.wara2a.embedding

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.sqrt

class E5EmbeddingMathTest {
    @Test
    fun `truncate keeps short sequences unchanged`() {
        val tokens = longArrayOf(0, 10, 20, 2)
        assertArrayEquals(tokens, E5EmbeddingMath.truncateTokenIds(tokens, maxTokens = 8))
    }

    @Test
    fun `truncate preserves trailing eos`() {
        val tokens = LongArray(20) { it.toLong() }
        tokens[19] = 2L
        val truncated = E5EmbeddingMath.truncateTokenIds(tokens, maxTokens = 8)
        assertEquals(8, truncated.size)
        assertEquals(0L, truncated[0])
        assertEquals(1L, truncated[1])
        assertEquals(2L, truncated[7])
    }

    @Test
    fun `mean pool ignores masked tokens then L2 normalizes`() {
        val fullHidden = FloatArray(3 * E5EmbeddingMath.DIMENSIONS)
        fullHidden[0] = 2f
        fullHidden[E5EmbeddingMath.DIMENSIONS] = 2f
        fullHidden[E5EmbeddingMath.DIMENSIONS * 2] = 100f
        val mask = floatArrayOf(1f, 1f, 0f)
        val vector = E5EmbeddingMath.meanPoolAndL2Normalize(
            hiddenStates = fullHidden,
            sequenceLength = 3,
            attentionMask = mask,
        )
        assertEquals(E5EmbeddingMath.DIMENSIONS, vector.size)
        assertEquals(1f, vector[0], 1e-5f)
        for (index in 1 until vector.size) {
            assertEquals(0f, vector[index], 1e-5f)
        }
        val norm = sqrt(vector.sumOf { (it * it).toDouble() })
        assertTrue(abs(norm - 1.0) < 1e-5)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects non finite hidden states`() {
        val hidden = FloatArray(E5EmbeddingMath.DIMENSIONS) { Float.NaN }
        E5EmbeddingMath.meanPoolAndL2Normalize(hidden, sequenceLength = 1)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects empty token sequence`() {
        E5EmbeddingMath.truncateTokenIds(longArrayOf())
    }
}
