// Copyright (c) 2026 PaddlePaddle Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.paddle.ocr

import android.graphics.Bitmap
import java.io.Closeable

/**
 * Serialized PP-OCRv5 detector + Arabic/Latin recognizer runtime.
 *
 * ONNX Runtime calls are synchronous and are deliberately not advertised as
 * interruptible. [checkpoint] is invoked between native calls so a caller can
 * suppress a cancelled result as soon as the current call returns.
 */
class PaddleOcrRuntime private constructor(
    private val sessions: OrtSessionStore,
    private val detectorConfig: DetectorModelConfig,
    private val arabicConfig: RecognizerModelConfig,
    private val latinConfig: RecognizerModelConfig,
) : Closeable {
    private var closed = false

    companion object {
        const val RUNTIME_DESCRIPTION =
            "PaddleOCR@2661c7c0 / ONNX Runtime 1.21.1 / OpenCV 4.13.0 (CPU)"

        fun create(
            modelFiles: OcrModelFiles,
            numThreads: Int = 4,
            checkpoint: () -> Unit = {},
        ): PaddleOcrRuntime {
            val files = modelFiles.validate()
            checkpoint()
            OpenCvLoader.ensureLoaded()
            checkpoint()
            val detectorConfig = ModelYamlParser.parseDetector(files.detectorConfig)
            val arabicConfig = ModelYamlParser.parseRecognizer(
                files.arabicConfig,
                RecognizerFamily.ARABIC,
            )
            val latinConfig = ModelYamlParser.parseRecognizer(
                files.latinConfig,
                RecognizerFamily.LATIN,
            )
            checkpoint()
            val sessions = OrtSessionStore.create(files, numThreads, checkpoint)
            return PaddleOcrRuntime(sessions, detectorConfig, arabicConfig, latinConfig)
        }
    }

    fun recognize(
        bitmap: Bitmap,
        checkpoint: () -> Unit = {},
    ): OcrRunResult {
        checkOpen()
        if (bitmap.width <= 0 || bitmap.height <= 0) throw PaddleOcrException.InvalidImage()
        val totalStart = System.nanoTime()
        val source = BitmapConverter.toBgr(bitmap)
        try {
            checkpoint()
            val detectionStart = System.nanoTime()
            val detectionInput = DetectorPreprocessor.preprocess(source, detectorConfig)
            checkpoint()
            val detectorOutput = sessions.runDetector(detectionInput.values, detectionInput.shape)
            checkpoint()
            val boxes = DbPostProcessor.process(detectorOutput, detectionInput, detectorConfig)
            val detectionMs = elapsedMilliseconds(detectionStart)

            var arabicRecognitionMs = 0L
            var latinRecognitionMs = 0L
            val recognized = mutableListOf<OcrLine>()
            for (box in boxes) {
                checkpoint()
                val crop = QuadCropper.crop(source, box)
                try {
                    if (crop.empty()) continue
                    val arabicInput = RecognizerPreprocessor.preprocess(crop, arabicConfig.imageMode)
                    checkpoint()
                    val arabicStart = System.nanoTime()
                    val arabic = CtcDecoder.decodeSingle(
                        sessions.runArabicRecognizer(arabicInput.values, arabicInput.shape),
                        arabicConfig.characters,
                        arabicConfig.modelName,
                        reverseArabic = true,
                    )
                    arabicRecognitionMs += elapsedMilliseconds(arabicStart)
                    checkpoint()

                    val latin = if (RecognitionPolicy.shouldRunLatin(arabic)) {
                        val latinInput = if (latinConfig.imageMode == arabicConfig.imageMode) {
                            arabicInput
                        } else {
                            RecognizerPreprocessor.preprocess(crop, latinConfig.imageMode)
                        }
                        val latinStart = System.nanoTime()
                        CtcDecoder.decodeSingle(
                            sessions.runLatinRecognizer(latinInput.values, latinInput.shape),
                            latinConfig.characters,
                            latinConfig.modelName,
                            reverseArabic = false,
                        ).also {
                            latinRecognitionMs += elapsedMilliseconds(latinStart)
                        }
                    } else {
                        null
                    }
                    checkpoint()
                    val selected = RecognitionPolicy.select(arabic, latin)
                    if (selected.text.isNotBlank()) {
                        recognized.add(
                            OcrLine(
                                text = selected.text,
                                box = box,
                                script = selected.script,
                                confidence = selected.confidence.coerceIn(0f, 1f),
                                recognizer = selected.recognizer,
                            ),
                        )
                    }
                } finally {
                    crop.release()
                }
            }
            checkpoint()
            return OcrRunResult(
                imageWidth = source.cols(),
                imageHeight = source.rows(),
                lines = ReadingOrder.sort(recognized),
                timings = OcrTimings(
                    detectionMs = detectionMs,
                    arabicRecognitionMs = arabicRecognitionMs,
                    latinRecognitionMs = latinRecognitionMs,
                    totalMs = elapsedMilliseconds(totalStart),
                ),
            )
        } catch (error: PaddleOcrException) {
            throw error
        } catch (error: Throwable) {
            throw PaddleOcrException.InferenceFailed("pipeline", error)
        } finally {
            source.release()
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        sessions.close()
    }

    private fun checkOpen() {
        if (closed) {
            throw PaddleOcrException.InferenceFailed(
                "lifecycle",
                IllegalStateException("OCR runtime is closed"),
            )
        }
    }

    private fun elapsedMilliseconds(startNanos: Long): Long =
        ((System.nanoTime() - startNanos) / 1_000_000L).coerceAtLeast(0L)
}
