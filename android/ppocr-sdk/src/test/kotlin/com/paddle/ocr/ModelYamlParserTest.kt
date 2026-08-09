package com.paddle.ocr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelYamlParserTest {
    @Test
    fun `detector config honors official resize and DB parameters`() {
        val config = ModelYamlParser.parseDetector(
            """
            Global:
              model_name: PP-OCRv5_mobile_det
            PreProcess:
              transform_ops:
              - DecodeImage:
                  img_mode: BGR
              - DetResizeForTest:
                  resize_long: 960
              - NormalizeImage:
                  scale: 1./255.
              - ToCHWImage: null
            PostProcess:
              name: DBPostProcess
              thresh: 0.3
              box_thresh: 0.6
              max_candidates: 1000
              unclip_ratio: 1.5
            """.trimIndent(),
        )

        assertEquals("resize_long", config.limitType)
        assertEquals(960, config.limitSideLen)
        assertEquals(1000, config.maxCandidates)
        assertEquals(0.6f, config.boxThreshold)
    }

    @Test
    fun `Arabic recognizer keeps YAML dictionary order and appends space`() {
        val config = ModelYamlParser.parseRecognizer(
            """
            Global:
              model_name: arabic_PP-OCRv5_mobile_rec
            PreProcess:
              transform_ops:
              - DecodeImage:
                  img_mode: BGR
              - RecResizeImg:
                  image_shape:
                  - 3
                  - 48
                  - 320
            PostProcess:
              name: CTCLabelDecode
              character_dict:
              - A
              - ا
              - '0'
            """.trimIndent(),
            RecognizerFamily.ARABIC,
        )

        assertEquals(listOf("A", "ا", "0", " "), config.characters)
        assertEquals("BGR", config.imageMode)
        assertTrue(config.modelName.startsWith("arabic_"))
    }
}
