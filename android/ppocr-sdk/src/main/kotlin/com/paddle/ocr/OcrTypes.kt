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

import java.io.File

data class OcrModelFiles(
    val detectorModelPath: String,
    val detectorConfigPath: String,
    val arabicModelPath: String,
    val arabicConfigPath: String,
    val latinModelPath: String,
    val latinConfigPath: String,
) {
    internal fun validate(): ValidatedOcrModelFiles = ValidatedOcrModelFiles(
        detectorModel = validateFile(detectorModelPath, "detector model", setOf("onnx")),
        detectorConfig = validateFile(detectorConfigPath, "detector config", setOf("yml", "yaml")),
        arabicModel = validateFile(arabicModelPath, "Arabic recognizer model", setOf("onnx")),
        arabicConfig = validateFile(arabicConfigPath, "Arabic recognizer config", setOf("yml", "yaml")),
        latinModel = validateFile(latinModelPath, "Latin recognizer model", setOf("onnx")),
        latinConfig = validateFile(latinConfigPath, "Latin recognizer config", setOf("yml", "yaml")),
    )

    private fun validateFile(path: String, label: String, extensions: Set<String>): File {
        if (path.isBlank()) throw PaddleOcrException.ModelNotInstalled("Missing $label path")
        val file = try {
            File(path).canonicalFile
        } catch (error: Throwable) {
            throw PaddleOcrException.ModelNotInstalled("Invalid $label path", error)
        }
        val extension = file.extension.lowercase()
        if (!file.isFile || !file.canRead() || file.length() <= 0L) {
            throw PaddleOcrException.ModelNotInstalled("$label is not installed or readable")
        }
        if (extension !in extensions) {
            throw PaddleOcrException.IncompatibleArtifact("$label has an unsupported file format")
        }
        return file
    }
}

internal data class ValidatedOcrModelFiles(
    val detectorModel: File,
    val detectorConfig: File,
    val arabicModel: File,
    val arabicConfig: File,
    val latinModel: File,
    val latinConfig: File,
)

data class OcrPoint(val x: Float, val y: Float)

data class OcrBox(val points: List<OcrPoint>) {
    init {
        require(points.size == 4) { "OCR box must contain four points" }
    }

    val centerX: Float get() = points.sumOf { it.x.toDouble() }.toFloat() / points.size
    val centerY: Float get() = points.sumOf { it.y.toDouble() }.toFloat() / points.size
    val height: Float
        get() = maxOf(
            distance(points[0], points[3]),
            distance(points[1], points[2]),
        )

    private fun distance(first: OcrPoint, second: OcrPoint): Float =
        kotlin.math.hypot(first.x - second.x, first.y - second.y)
}

enum class OcrScript(val wireName: String) {
    ARABIC("arabic"),
    LATIN("latin"),
    NUMERIC("numeric"),
    MIXED("mixed"),
    UNKNOWN("unknown"),
}

data class OcrLine(
    val text: String,
    val box: OcrBox,
    val script: OcrScript,
    val confidence: Float,
    val recognizer: String,
)

data class OcrTimings(
    val detectionMs: Long,
    val arabicRecognitionMs: Long,
    val latinRecognitionMs: Long,
    val totalMs: Long,
)

data class OcrRunResult(
    val imageWidth: Int,
    val imageHeight: Int,
    val lines: List<OcrLine>,
    val timings: OcrTimings,
)

sealed class PaddleOcrException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class ModelNotInstalled(message: String, cause: Throwable? = null) : PaddleOcrException(message, cause)
    class IncompatibleArtifact(message: String, cause: Throwable? = null) : PaddleOcrException(message, cause)
    class InitializationFailed(message: String, cause: Throwable? = null) : PaddleOcrException(message, cause)
    class InvalidImage(message: String = "The invoice image is invalid", cause: Throwable? = null) :
        PaddleOcrException(message, cause)
    class InferenceFailed(stage: String, cause: Throwable) :
        PaddleOcrException("OCR inference failed during $stage", cause)
}
