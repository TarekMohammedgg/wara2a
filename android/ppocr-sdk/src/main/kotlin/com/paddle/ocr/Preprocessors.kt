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
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import kotlin.math.ceil
import kotlin.math.floor

internal object OpenCvLoader {
    @Volatile private var loaded = false

    @Synchronized
    fun ensureLoaded() {
        if (loaded) return
        try {
            System.loadLibrary("opencv_java4")
            loaded = true
        } catch (error: Throwable) {
            throw PaddleOcrException.InitializationFailed("OpenCV 4.5.3 is unavailable", error)
        }
    }
}

internal data class DetectionInput(
    val values: FloatArray,
    val shape: LongArray,
    val originalWidth: Int,
    val originalHeight: Int,
)

internal data class RecognitionInput(
    val values: FloatArray,
    val shape: LongArray,
)

internal object BitmapConverter {
    fun toBgr(bitmap: Bitmap): Mat {
        if (bitmap.width <= 0 || bitmap.height <= 0) throw PaddleOcrException.InvalidImage()
        val safeBitmap = if (bitmap.config == Bitmap.Config.ARGB_8888) {
            bitmap
        } else {
            bitmap.copy(Bitmap.Config.ARGB_8888, false)
                ?: throw PaddleOcrException.InvalidImage("The invoice bitmap could not be converted")
        }
        val rgba = Mat(safeBitmap.height, safeBitmap.width, CvType.CV_8UC4)
        val bgr = Mat()
        return try {
            Utils.bitmapToMat(safeBitmap, rgba)
            Imgproc.cvtColor(rgba, bgr, Imgproc.COLOR_RGBA2BGR)
            bgr
        } catch (error: Throwable) {
            bgr.release()
            throw PaddleOcrException.InvalidImage("The invoice bitmap could not be decoded", error)
        } finally {
            rgba.release()
            if (safeBitmap !== bitmap) safeBitmap.recycle()
        }
    }
}

internal object DetectorPreprocessor {
    private val mean = doubleArrayOf(0.485, 0.456, 0.406)
    private val standardDeviation = doubleArrayOf(0.229, 0.224, 0.225)
    private const val SCALE = 1.0 / 255.0

    fun preprocess(source: Mat, config: DetectorModelConfig): DetectionInput {
        if (source.empty()) throw PaddleOcrException.InvalidImage()
        val originalHeight = source.rows()
        val originalWidth = source.cols()
        val colorInput = if (config.imageMode == "RGB") {
            Mat().also { Imgproc.cvtColor(source, it, Imgproc.COLOR_BGR2RGB) }
        } else {
            source
        }
        val resized = try {
            resizeToMultipleOf32(
                colorInput,
                config.limitSideLen,
                config.limitType,
                config.maxSideLimit,
            )
        } finally {
            if (colorInput !== source) colorInput.release()
        }

        val height = resized.rows()
        val width = resized.cols()
        val floatMat = Mat(height, width, CvType.CV_32FC3)
        val channels = mutableListOf<Mat>()
        try {
            resized.convertTo(floatMat, CvType.CV_32F)
            Core.split(floatMat, channels)
            for (channel in 0..2) {
                Core.multiply(channels[channel], Scalar(SCALE), channels[channel])
                Core.subtract(channels[channel], Scalar(mean[channel]), channels[channel])
                Core.divide(channels[channel], Scalar(standardDeviation[channel]), channels[channel])
            }
            val channelSize = height * width
            val tensor = FloatArray(3 * channelSize)
            for (channel in 0..2) {
                val values = FloatArray(channelSize)
                channels[channel].get(0, 0, values)
                System.arraycopy(values, 0, tensor, channel * channelSize, channelSize)
            }
            return DetectionInput(
                values = tensor,
                shape = longArrayOf(1, 3, height.toLong(), width.toLong()),
                originalWidth = originalWidth,
                originalHeight = originalHeight,
            )
        } finally {
            channels.forEach(Mat::release)
            floatMat.release()
            resized.release()
        }
    }

    private fun resizeToMultipleOf32(
        source: Mat,
        limitSideLength: Int,
        limitType: String,
        maxSideLimit: Int,
    ): Mat {
        val height = source.rows()
        val width = source.cols()
        var ratio = when (limitType) {
            "max" -> if (maxOf(height, width) > limitSideLength) {
                limitSideLength.toDouble() / maxOf(height, width)
            } else {
                1.0
            }
            "min" -> if (minOf(height, width) < limitSideLength) {
                limitSideLength.toDouble() / minOf(height, width)
            } else {
                1.0
            }
            "resize_long" -> limitSideLength.toDouble() / maxOf(height, width)
            else -> throw PaddleOcrException.IncompatibleArtifact("Unsupported detector resize mode")
        }

        var newHeight = (height * ratio).toInt().coerceAtLeast(1)
        var newWidth = (width * ratio).toInt().coerceAtLeast(1)
        if (maxOf(newHeight, newWidth) > maxSideLimit) {
            ratio = maxSideLimit.toDouble() / maxOf(newHeight, newWidth)
            newHeight = (newHeight * ratio).toInt().coerceAtLeast(1)
            newWidth = (newWidth * ratio).toInt().coerceAtLeast(1)
        }
        newHeight = maxOf(roundHalfToEven(newHeight / 32.0) * 32, 32)
        newWidth = maxOf(roundHalfToEven(newWidth / 32.0) * 32, 32)
        return Mat().also {
            Imgproc.resize(
                source,
                it,
                Size(newWidth.toDouble(), newHeight.toDouble()),
                0.0,
                0.0,
                Imgproc.INTER_LINEAR,
            )
        }
    }

    private fun roundHalfToEven(value: Double): Int {
        val lower = floor(value)
        val difference = value - lower
        return when {
            difference < 0.5 -> lower.toInt()
            difference > 0.5 -> lower.toInt() + 1
            lower.toInt() % 2 == 0 -> lower.toInt()
            else -> lower.toInt() + 1
        }
    }
}

internal object RecognizerPreprocessor {
    private const val FIXED_HEIGHT = 48
    private const val MAX_WIDTH = 3200

    fun preprocess(crop: Mat, imageMode: String): RecognitionInput {
        if (crop.empty()) throw PaddleOcrException.InvalidImage("A detected text crop is empty")
        val colorInput = if (imageMode == "RGB") {
            Mat().also { Imgproc.cvtColor(crop, it, Imgproc.COLOR_BGR2RGB) }
        } else {
            crop
        }
        val resized = Mat()
        val floatMat = Mat()
        val channels = mutableListOf<Mat>()
        try {
            val aspectRatio = crop.cols().toDouble() / crop.rows().coerceAtLeast(1)
            val width = ceil(FIXED_HEIGHT * aspectRatio).toInt().coerceIn(1, MAX_WIDTH)
            Imgproc.resize(
                colorInput,
                resized,
                Size(width.toDouble(), FIXED_HEIGHT.toDouble()),
                0.0,
                0.0,
                Imgproc.INTER_LINEAR,
            )
            resized.convertTo(floatMat, CvType.CV_32F)
            Core.divide(floatMat, Scalar(127.5, 127.5, 127.5), floatMat)
            Core.subtract(floatMat, Scalar(1.0, 1.0, 1.0), floatMat)
            Core.split(floatMat, channels)

            val channelSize = FIXED_HEIGHT * width
            val tensor = FloatArray(3 * channelSize)
            for (channel in 0..2) {
                val values = FloatArray(channelSize)
                channels[channel].get(0, 0, values)
                System.arraycopy(values, 0, tensor, channel * channelSize, channelSize)
            }
            return RecognitionInput(
                values = tensor,
                shape = longArrayOf(1, 3, FIXED_HEIGHT.toLong(), width.toLong()),
            )
        } finally {
            channels.forEach(Mat::release)
            floatMat.release()
            resized.release()
            if (colorInput !== crop) colorInput.release()
        }
    }
}
