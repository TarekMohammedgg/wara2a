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

internal data class RecognitionCandidate(
    val text: String,
    val confidence: Float,
    val script: OcrScript,
    val recognizer: String,
)

internal object CtcDecoder {
    private const val BLANK_INDEX = 0

    fun decodeSingle(
        output: TensorOutput,
        characters: List<String>,
        recognizer: String,
        reverseArabic: Boolean,
    ): RecognitionCandidate {
        if (output.shape.size != 3 || output.shape[0] != 1L) {
            throw PaddleOcrException.IncompatibleArtifact(
                "$recognizer output must have shape [1, time, classes]",
            )
        }
        val timeSteps = output.shape[1].toInt()
        val classCount = output.shape[2].toInt()
        if (timeSteps <= 0 || classCount != characters.size + 1) {
            throw PaddleOcrException.IncompatibleArtifact(
                "$recognizer ONNX output classes do not match its YAML character dictionary",
            )
        }
        if (output.values.size < timeSteps * classCount) {
            throw PaddleOcrException.IncompatibleArtifact("$recognizer output tensor is truncated")
        }

        val text = StringBuilder()
        val retainedProbabilities = mutableListOf<Float>()
        var previousIndex = -1
        for (time in 0 until timeSteps) {
            val offset = time * classCount
            var maximumIndex = 0
            var maximumValue = output.values[offset]
            for (characterIndex in 1 until classCount) {
                val value = output.values[offset + characterIndex]
                if (value > maximumValue) {
                    maximumValue = value
                    maximumIndex = characterIndex
                }
            }
            if (maximumIndex != BLANK_INDEX && maximumIndex != previousIndex) {
                text.append(characters[maximumIndex - 1])
                if (maximumValue.isFinite()) retainedProbabilities.add(maximumValue.coerceIn(0f, 1f))
            }
            previousIndex = maximumIndex
        }
        val temporalText = text.toString()
        val decoded = if (reverseArabic) {
            ArabicPredictionOrder.reverse(temporalText)
        } else {
            temporalText
        }.trim()
        val confidence = if (retainedProbabilities.isEmpty()) {
            0f
        } else {
            retainedProbabilities.average().toFloat().coerceIn(0f, 1f)
        }
        return RecognitionCandidate(
            text = decoded,
            confidence = confidence,
            script = ScriptClassifier.classify(decoded),
            recognizer = recognizer,
        )
    }
}

internal object ArabicPredictionOrder {
    private val preservedRunCharacter = Regex("[a-zA-Z0-9 :*./%+\\-]")

    /** Exact Kotlin equivalent of PaddleOCR BaseRecLabelDecode.pred_reverse. */
    fun reverse(prediction: String): String {
        val segments = mutableListOf<String>()
        val currentRun = StringBuilder()
        prediction.codePoints().forEach { codePoint ->
            val character = String(Character.toChars(codePoint))
            if (preservedRunCharacter.matches(character)) {
                currentRun.append(character)
            } else {
                if (currentRun.isNotEmpty()) {
                    segments.add(currentRun.toString())
                    currentRun.clear()
                }
                segments.add(character)
            }
        }
        if (currentRun.isNotEmpty()) segments.add(currentRun.toString())
        return segments.asReversed().joinToString(separator = "")
    }
}

internal object ScriptClassifier {
    fun classify(text: String): OcrScript {
        val arabic = arabicCount(text)
        val latin = latinCount(text)
        val digits = text.codePoints().filter(Character::isDigit).count().toInt()
        return when {
            arabic > 0 && latin > 0 -> OcrScript.MIXED
            arabic > 0 -> OcrScript.ARABIC
            latin > 0 -> OcrScript.LATIN
            digits > 0 -> OcrScript.NUMERIC
            else -> OcrScript.UNKNOWN
        }
    }

    fun arabicCount(text: String): Int = text.codePoints().filter { codePoint ->
        !Character.isDigit(codePoint) &&
            Character.UnicodeScript.of(codePoint) == Character.UnicodeScript.ARABIC
    }.count().toInt()

    fun latinCount(text: String): Int = text.codePoints().filter { codePoint ->
        Character.UnicodeScript.of(codePoint) == Character.UnicodeScript.LATIN
    }.count().toInt()
}

internal object RecognitionPolicy {
    private const val HIGH_CONFIDENCE_ARABIC = 0.92f

    fun shouldRunLatin(arabic: RecognitionCandidate): Boolean =
        arabic.text.isBlank() ||
            arabic.script != OcrScript.ARABIC ||
            arabic.confidence < HIGH_CONFIDENCE_ARABIC

    fun select(
        arabic: RecognitionCandidate,
        latin: RecognitionCandidate?,
    ): RecognitionCandidate {
        if (latin == null) return arabic
        if (arabic.text.isBlank()) return latin
        if (latin.text.isBlank()) return arabic

        val arabicContainsArabic = arabic.script == OcrScript.ARABIC || arabic.script == OcrScript.MIXED
        if (arabicContainsArabic && arabic.confidence + 0.12f >= latin.confidence) return arabic

        val arabicScore = arabic.confidence + when (arabic.script) {
            OcrScript.ARABIC, OcrScript.MIXED -> 0.08f
            OcrScript.NUMERIC -> 0.01f
            else -> 0f
        }
        val latinScore = latin.confidence + when (latin.script) {
            OcrScript.LATIN -> 0.04f
            OcrScript.NUMERIC -> 0.01f
            else -> 0f
        }
        return if (latinScore > arabicScore) latin else arabic
    }
}
