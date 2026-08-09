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

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.Closeable
import java.io.File
import java.nio.FloatBuffer

internal class OrtSessionStore private constructor(
    private val environment: OrtEnvironment,
    private val detector: SessionHandle,
    private val arabicRecognizer: SessionHandle,
    private val latinRecognizer: SessionHandle,
) : Closeable {
    private var closed = false

    companion object {
        fun create(
            files: ValidatedOcrModelFiles,
            numThreads: Int,
            checkpoint: () -> Unit,
        ): OrtSessionStore {
            val environment = try {
                OrtEnvironment.getEnvironment()
            } catch (error: Throwable) {
                throw PaddleOcrException.InitializationFailed("ONNX Runtime is unavailable", error)
            }
            val options = OrtSession.SessionOptions().apply {
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                setIntraOpNumThreads(numThreads.coerceIn(1, 8))
            }
            var detector: SessionHandle? = null
            var arabic: SessionHandle? = null
            var latin: SessionHandle? = null
            try {
                checkpoint()
                detector = createHandle(environment, files.detectorModel, options, "detector")
                checkpoint()
                arabic = createHandle(environment, files.arabicModel, options, "Arabic recognizer")
                checkpoint()
                latin = createHandle(environment, files.latinModel, options, "Latin recognizer")
                checkpoint()
                return OrtSessionStore(environment, detector, arabic, latin)
            } catch (error: PaddleOcrException) {
                closePartial(latin, arabic, detector)
                throw error
            } catch (error: Throwable) {
                closePartial(latin, arabic, detector)
                throw PaddleOcrException.InitializationFailed("OCR model sessions could not be created", error)
            } finally {
                options.close()
            }
        }

        private fun createHandle(
            environment: OrtEnvironment,
            model: File,
            options: OrtSession.SessionOptions,
            label: String,
        ): SessionHandle {
            val session = try {
                environment.createSession(model.absolutePath, options)
            } catch (error: Throwable) {
                throw PaddleOcrException.InitializationFailed("$label ONNX model could not be loaded", error)
            }
            return try {
                val inputName = session.inputNames.firstOrNull()
                    ?: throw IllegalArgumentException("Model has no input tensor")
                val outputName = session.outputNames.firstOrNull()
                    ?: throw IllegalArgumentException("Model has no output tensor")
                SessionHandle(session, inputName, outputName, label)
            } catch (error: Throwable) {
                session.close()
                throw PaddleOcrException.InitializationFailed("$label ONNX signature is invalid", error)
            }
        }

        private fun closePartial(vararg handles: SessionHandle?) {
            handles.forEach { handle -> runCatching { handle?.session?.close() } }
        }
    }

    fun runDetector(input: FloatArray, shape: LongArray): TensorOutput =
        run(detector, input, shape)

    fun runArabicRecognizer(input: FloatArray, shape: LongArray): TensorOutput =
        run(arabicRecognizer, input, shape)

    fun runLatinRecognizer(input: FloatArray, shape: LongArray): TensorOutput =
        run(latinRecognizer, input, shape)

    private fun run(handle: SessionHandle, input: FloatArray, shape: LongArray): TensorOutput {
        if (closed) {
            throw PaddleOcrException.InferenceFailed(handle.label, IllegalStateException("Session is closed"))
        }
        val tensor = try {
            OnnxTensor.createTensor(environment, FloatBuffer.wrap(input), shape)
        } catch (error: Throwable) {
            throw PaddleOcrException.InferenceFailed(handle.label, error)
        }
        val result = try {
            try {
                handle.session.run(mapOf(handle.inputName to tensor))
            } catch (error: Throwable) {
                throw PaddleOcrException.InferenceFailed(handle.label, error)
            }
        } finally {
            tensor.close()
        }
        return try {
            val value = result.get(handle.outputName)
                .orElseThrow { IllegalStateException("Model output is missing") }
            val output = value as? OnnxTensor
                ?: throw IllegalStateException("Model output is not a tensor")
            TensorOutput(copy(output.floatBuffer), output.info.shape.copyOf())
        } catch (error: PaddleOcrException) {
            throw error
        } catch (error: Throwable) {
            throw PaddleOcrException.InferenceFailed(handle.label, error)
        } finally {
            result.close()
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        try {
            latinRecognizer.session.close()
        } finally {
            try {
                arabicRecognizer.session.close()
            } finally {
                detector.session.close()
            }
        }
    }

    private fun copy(buffer: FloatBuffer): FloatArray {
        val duplicate = buffer.duplicate()
        duplicate.rewind()
        return FloatArray(duplicate.remaining()).also(duplicate::get)
    }

    private data class SessionHandle(
        val session: OrtSession,
        val inputName: String,
        val outputName: String,
        val label: String,
    )
}

internal data class TensorOutput(val values: FloatArray, val shape: LongArray)
