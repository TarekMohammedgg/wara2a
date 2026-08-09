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

internal data class DetectorModelConfig(
    val modelName: String,
    val imageMode: String,
    val limitSideLen: Int,
    val limitType: String,
    val maxSideLimit: Int,
    val threshold: Float,
    val boxThreshold: Float,
    val unclipRatio: Float,
    val maxCandidates: Int,
    val useDilation: Boolean,
    val scoreMode: String,
    val boxType: String,
)

internal data class RecognizerModelConfig(
    val modelName: String,
    val imageMode: String,
    val characters: List<String>,
)

internal enum class RecognizerFamily { ARABIC, LATIN }

internal object ModelYamlParser {
    private const val MAX_CONFIG_BYTES = 2L * 1024L * 1024L

    fun parseDetector(file: File): DetectorModelConfig = parseDetector(readConfig(file))

    fun parseRecognizer(file: File, family: RecognizerFamily): RecognizerModelConfig =
        parseRecognizer(readConfig(file), family)

    internal fun parseDetector(content: String): DetectorModelConfig {
        val modelName = requiredScalar(section(content, "Global"), "model_name", "detector model_name")
        if (modelName != "PP-OCRv5_mobile_det") {
            throw PaddleOcrException.IncompatibleArtifact(
                "Detector config must declare PP-OCRv5_mobile_det",
            )
        }

        val preprocess = section(content, "PreProcess")
        requireMarker(preprocess, "DecodeImage:", "detector DecodeImage")
        requireMarker(preprocess, "NormalizeImage:", "detector NormalizeImage")
        requireMarker(preprocess, "ToCHWImage:", "detector ToCHWImage")
        val imageMode = scalar(preprocess, "img_mode")?.uppercase() ?: "BGR"
        if (imageMode !in setOf("BGR", "RGB")) {
            throw PaddleOcrException.IncompatibleArtifact("Unsupported detector image mode")
        }

        val resizeLong = scalar(preprocess, "resize_long")?.toIntOrNull()
        val limitSideLen = resizeLong ?: scalar(preprocess, "limit_side_len")?.toIntOrNull() ?: 64
        val limitType = if (resizeLong != null) {
            "resize_long"
        } else {
            scalar(preprocess, "limit_type")?.lowercase() ?: "min"
        }
        if (limitSideLen <= 0 || limitType !in setOf("min", "max", "resize_long")) {
            throw PaddleOcrException.IncompatibleArtifact("Unsupported detector resize configuration")
        }

        val postprocess = section(content, "PostProcess")
        if (requiredScalar(postprocess, "name", "detector postprocess") != "DBPostProcess") {
            throw PaddleOcrException.IncompatibleArtifact("Detector postprocess must be DBPostProcess")
        }
        val boxType = scalar(postprocess, "box_type")?.lowercase() ?: "quad"
        if (boxType != "quad") {
            throw PaddleOcrException.IncompatibleArtifact("Only quadrilateral detector output is supported")
        }

        return DetectorModelConfig(
            modelName = modelName,
            imageMode = imageMode,
            limitSideLen = limitSideLen,
            limitType = limitType,
            maxSideLimit = scalar(preprocess, "max_side_limit")?.toIntOrNull() ?: 4000,
            threshold = scalar(postprocess, "thresh")?.toFloatOrNull() ?: 0.3f,
            boxThreshold = scalar(postprocess, "box_thresh")?.toFloatOrNull() ?: 0.6f,
            unclipRatio = scalar(postprocess, "unclip_ratio")?.toFloatOrNull() ?: 1.5f,
            maxCandidates = scalar(postprocess, "max_candidates")?.toIntOrNull() ?: 3000,
            useDilation = scalar(postprocess, "use_dilation")?.toBooleanStrictOrNull() ?: false,
            scoreMode = scalar(postprocess, "score_mode")?.lowercase() ?: "fast",
            boxType = boxType,
        ).also(::validateDetectorValues)
    }

    internal fun parseRecognizer(content: String, family: RecognizerFamily): RecognizerModelConfig {
        val modelName = requiredScalar(section(content, "Global"), "model_name", "recognizer model_name")
        val validName = when (family) {
            RecognizerFamily.ARABIC -> modelName == "arabic_PP-OCRv5_mobile_rec"
            RecognizerFamily.LATIN ->
                modelName == "latin_PP-OCRv5_mobile_rec" || modelName == "en_PP-OCRv5_mobile_rec"
        }
        if (!validName) {
            throw PaddleOcrException.IncompatibleArtifact(
                "Recognizer config does not match the requested ${family.name.lowercase()} PP-OCRv5 model",
            )
        }

        val preprocess = section(content, "PreProcess")
        requireMarker(preprocess, "DecodeImage:", "recognizer DecodeImage")
        requireMarker(preprocess, "RecResizeImg:", "recognizer RecResizeImg")
        val imageMode = scalar(preprocess, "img_mode")?.uppercase() ?: "BGR"
        if (imageMode !in setOf("BGR", "RGB")) {
            throw PaddleOcrException.IncompatibleArtifact("Unsupported recognizer image mode")
        }
        val shape = yamlIntegerList(preprocess, "image_shape")
        if (shape.size < 3 || shape[0] != 3 || shape[1] != 48) {
            throw PaddleOcrException.IncompatibleArtifact(
                "Recognizer input must use the supported [3, 48, width] shape",
            )
        }

        val postprocess = section(content, "PostProcess")
        if (requiredScalar(postprocess, "name", "recognizer postprocess") != "CTCLabelDecode") {
            throw PaddleOcrException.IncompatibleArtifact("Recognizer postprocess must be CTCLabelDecode")
        }
        val characters = yamlStringList(postprocess, "character_dict").toMutableList()
        if (characters.isEmpty()) {
            throw PaddleOcrException.IncompatibleArtifact("Recognizer character dictionary is empty")
        }
        if (characters.lastOrNull() != " ") characters.add(" ")
        return RecognizerModelConfig(
            modelName = modelName,
            imageMode = imageMode,
            characters = characters,
        )
    }

    private fun validateDetectorValues(config: DetectorModelConfig) {
        if (config.maxSideLimit < 32 || config.maxCandidates <= 0) {
            throw PaddleOcrException.IncompatibleArtifact("Detector limits are invalid")
        }
        if (config.threshold !in 0f..1f || config.boxThreshold !in 0f..1f || config.unclipRatio <= 0f) {
            throw PaddleOcrException.IncompatibleArtifact("Detector thresholds are invalid")
        }
        if (config.scoreMode !in setOf("fast", "slow")) {
            throw PaddleOcrException.IncompatibleArtifact("Detector score mode is unsupported")
        }
    }

    private fun readConfig(file: File): String {
        if (file.length() > MAX_CONFIG_BYTES) {
            throw PaddleOcrException.IncompatibleArtifact("OCR model config is unexpectedly large")
        }
        return try {
            file.readText(Charsets.UTF_8)
        } catch (error: Throwable) {
            throw PaddleOcrException.IncompatibleArtifact("OCR model config cannot be read", error)
        }
    }

    private fun section(content: String, name: String): List<String> {
        val lines = normalizedLines(content)
        val index = lines.indexOfFirst { it.trim() == "$name:" }
        if (index < 0) throw PaddleOcrException.IncompatibleArtifact("Missing $name section")
        val baseIndent = leadingSpaces(lines[index])
        val output = mutableListOf<String>()
        for (lineIndex in index + 1 until lines.size) {
            val line = lines[lineIndex]
            if (line.isBlank() || line.trimStart().startsWith("#")) {
                output.add(line)
                continue
            }
            if (leadingSpaces(line) <= baseIndent) break
            output.add(line)
        }
        return output
    }

    private fun requiredScalar(lines: List<String>, key: String, label: String): String =
        scalar(lines, key) ?: throw PaddleOcrException.IncompatibleArtifact("Missing $label")

    private fun scalar(lines: List<String>, key: String): String? {
        for (line in lines) {
            val trimmed = line.trim()
            if (!trimmed.startsWith("$key:")) continue
            return parseScalar(trimmed.substringAfter(':'))
        }
        return null
    }

    private fun requireMarker(lines: List<String>, marker: String, label: String) {
        if (lines.none { line ->
                val trimmed = line.trim().removePrefix("- ")
                trimmed.startsWith(marker)
            }
        ) {
            throw PaddleOcrException.IncompatibleArtifact("Missing $label")
        }
    }

    private fun yamlIntegerList(lines: List<String>, key: String): List<Int> {
        val raw = yamlRawList(lines, key)
        return raw.mapNotNull { parseScalar(it).toIntOrNull() }
    }

    private fun yamlStringList(lines: List<String>, key: String): List<String> =
        yamlRawList(lines, key).map(::parseScalar)

    private fun yamlRawList(lines: List<String>, key: String): List<String> {
        val keyIndex = lines.indexOfFirst { it.trim() == "$key:" }
        if (keyIndex < 0) return emptyList()
        val keyIndent = leadingSpaces(lines[keyIndex])
        val values = mutableListOf<String>()
        for (index in keyIndex + 1 until lines.size) {
            val line = lines[index]
            if (line.isBlank() || line.trimStart().startsWith("#")) continue
            val indent = leadingSpaces(line)
            val trimmed = line.trimStart()
            if (indent < keyIndent || (indent == keyIndent && !trimmed.startsWith("-"))) break
            if (!trimmed.startsWith("-")) break
            values.add(trimmed.substring(1))
        }
        return values
    }

    private fun parseScalar(raw: String): String {
        val value = raw.trim()
        if (value.length >= 2 && value.first() == '\'' && value.last() == '\'') {
            return value.substring(1, value.length - 1).replace("''", "'")
        }
        if (value.length >= 2 && value.first() == '"' && value.last() == '"') {
            return value.substring(1, value.length - 1)
                .replace("\\\"", "\"")
                .replace("\\\\", "\\")
                .replace("\\n", "\n")
                .replace("\\r", "\r")
                .replace("\\t", "\t")
        }
        return value
    }

    private fun normalizedLines(content: String): List<String> =
        content.replace("\r\n", "\n").replace('\r', '\n').lines()

    private fun leadingSpaces(line: String): Int =
        line.indexOfFirst { it != ' ' }.let { if (it < 0) line.length else it }
}
