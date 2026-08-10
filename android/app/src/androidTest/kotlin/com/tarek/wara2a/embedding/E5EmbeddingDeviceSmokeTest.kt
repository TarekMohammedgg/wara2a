package com.tarek.wara2a.embedding

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Physical-device smoke for the pinned multilingual-E5 runtime.
 *
 * Requires the verified encoder at:
 * `/sdcard/Download/wara2a-e5/model_qint8_avx512_vnni.onnx`
 */
@RunWith(AndroidJUnit4::class)
class E5EmbeddingDeviceSmokeTest {
    @Test
    fun embedsArabicEnglishAndMixedQueries() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val model = File("/sdcard/Download/wara2a-e5/model_qint8_avx512_vnni.onnx")
        assumeTrue(
            "Push the pinned E5 ONNX to ${model.absolutePath} before device smoke.",
            model.isFile && model.length() == 118_346_824L,
        )

        val runtime = E5EmbeddingRuntime.create(context, model.absolutePath)
        try {
            val samples = listOf(
                "query: task: search result | query: فاتورة الغسالة من توكيل العربي",
                "query: task: search result | query: office chair receipt",
                "query: task: search result | query: Samsung S25 Ultra فاتورة Vodafone",
            )
            for (text in samples) {
                val started = System.nanoTime()
                val result = runtime.embed(text)
                val elapsedMs = (System.nanoTime() - started) / 1_000_000.0
                assertEquals(E5EmbeddingMath.DIMENSIONS, result.dimensions)
                assertEquals(E5EmbeddingMath.MODEL_ID, result.modelId)
                assertEquals(E5EmbeddingMath.DIMENSIONS, result.embedding.size)
                assertTrue(result.embedding.all { it.isFinite() })
                val norm = sqrt(result.embedding.sumOf { it * it })
                assertTrue(abs(norm - 1.0) < 1e-4)
                android.util.Log.i(
                    "Wara2aE5Smoke",
                    "ok tokens=${result.tokenCount} elapsedMs=$elapsedMs text=${text.take(48)}",
                )
            }
        } finally {
            runtime.close()
        }
    }
}
