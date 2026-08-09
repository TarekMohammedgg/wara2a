package com.paddle.ocr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecognitionPolicyTest {
    @Test
    fun `high confidence Arabic avoids the second recognizer`() {
        val candidate = RecognitionCandidate(
            text = "الإجمالي",
            confidence = 0.96f,
            script = OcrScript.ARABIC,
            recognizer = "arabic_PP-OCRv5_mobile_rec",
        )
        assertFalse(RecognitionPolicy.shouldRunLatin(candidate))
    }

    @Test
    fun `Latin output is selected when Arabic model also emits Latin less confidently`() {
        val arabic = RecognitionCandidate("TOTAL", 0.70f, OcrScript.LATIN, "arabic")
        val latin = RecognitionCandidate("TOTAL", 0.90f, OcrScript.LATIN, "latin")
        assertTrue(RecognitionPolicy.shouldRunLatin(arabic))
        assertEquals("latin", RecognitionPolicy.select(arabic, latin).recognizer)
    }

    @Test
    fun `Arabic dominated row is ordered right to left without reversing text`() {
        val right = line("الإجمالي", 120f, 10f)
        val left = line("١٢٥٫٠٠", 20f, 10f)
        val ordered = ReadingOrder.sort(listOf(left, right))
        assertEquals(listOf("الإجمالي", "١٢٥٫٠٠"), ordered.map(OcrLine::text))
    }

    @Test
    fun `official Arabic prediction reversal preserves Latin and numeric runs`() {
        assertEquals("حلويات", ArabicPredictionOrder.reverse("تايولح"))
        assertEquals("حلوياتABC 123", ArabicPredictionOrder.reverse("ABC 123تايولح"))
    }

    @Test
    fun `Arabic Indic and Persian digit-only evidence is numeric`() {
        assertEquals(OcrScript.NUMERIC, ScriptClassifier.classify("١٢٣۴۵"))
    }

    private fun line(text: String, x: Float, y: Float): OcrLine = OcrLine(
        text = text,
        box = OcrBox(
            listOf(
                OcrPoint(x, y),
                OcrPoint(x + 40f, y),
                OcrPoint(x + 40f, y + 12f),
                OcrPoint(x, y + 12f),
            ),
        ),
        script = ScriptClassifier.classify(text),
        confidence = 0.9f,
        recognizer = "fixture",
    )
}
