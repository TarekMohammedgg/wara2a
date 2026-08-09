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

import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.sin

internal object DbPostProcessor {
    private const val MIN_SIZE_BEFORE_UNCLIP = 3f
    private const val MIN_SIZE_AFTER_UNCLIP = 5f

    fun process(
        output: TensorOutput,
        input: DetectionInput,
        config: DetectorModelConfig,
    ): List<OcrBox> {
        if (output.shape.size != 4 || output.shape[2] <= 0 || output.shape[3] <= 0) {
            throw PaddleOcrException.InferenceFailed(
                "detector output",
                IllegalArgumentException("Expected a four-dimensional detector tensor"),
            )
        }
        val predictionHeight = output.shape[2].toInt()
        val predictionWidth = output.shape[3].toInt()
        if (output.values.size < predictionHeight * predictionWidth) {
            throw PaddleOcrException.InferenceFailed(
                "detector output",
                IllegalArgumentException("Detector output tensor is truncated"),
            )
        }
        val scaleX = input.originalWidth.toDouble() / predictionWidth
        val scaleY = input.originalHeight.toDouble() / predictionHeight
        val probability = Mat(predictionHeight, predictionWidth, CvType.CV_32FC1)
        val mask = Mat(predictionHeight, predictionWidth, CvType.CV_8UC1)
        val contours = mutableListOf<MatOfPoint>()
        val hierarchy = Mat()
        var contourMask = mask
        return try {
            probability.put(0, 0, output.values)
            val threshold = Mat()
            try {
                Imgproc.threshold(
                    probability,
                    threshold,
                    config.threshold.toDouble(),
                    255.0,
                    Imgproc.THRESH_BINARY,
                )
                threshold.convertTo(mask, CvType.CV_8UC1)
            } finally {
                threshold.release()
            }
            contourMask = if (config.useDilation) {
                val kernel = Mat.ones(2, 2, CvType.CV_8UC1)
                try {
                    Mat().also { Imgproc.dilate(mask, it, kernel) }
                } finally {
                    kernel.release()
                }
            } else {
                mask
            }
            Imgproc.findContours(
                contourMask,
                contours,
                hierarchy,
                Imgproc.RETR_LIST,
                Imgproc.CHAIN_APPROX_SIMPLE,
            )
            val boxes = mutableListOf<OcrBox>()
            for (index in 0 until minOf(contours.size, config.maxCandidates)) {
                val contour = contours[index]
                val contour2f = MatOfPoint2f(*contour.toArray())
                val rectangle = try {
                    Imgproc.minAreaRect(contour2f)
                } finally {
                    contour2f.release()
                }
                if (minOf(rectangle.size.width, rectangle.size.height) < MIN_SIZE_BEFORE_UNCLIP) continue
                val rectanglePoints = Array(4) { Point() }
                rectangle.points(rectanglePoints)
                val ordered = QuadGeometry.order(rectanglePoints)
                val score = if (config.scoreMode == "slow") {
                    boxScore(probability, contour.toList())
                } else {
                    boxScore(probability, ordered)
                }
                if (score < config.boxThreshold) continue

                val expanded = PolygonUnclip.expand(ordered, config.unclipRatio)
                val expandedInput = MatOfPoint2f()
                val expandedRectangle = try {
                    expandedInput.fromList(expanded)
                    Imgproc.minAreaRect(expandedInput)
                } finally {
                    expandedInput.release()
                }
                if (minOf(expandedRectangle.size.width, expandedRectangle.size.height) < MIN_SIZE_AFTER_UNCLIP) {
                    continue
                }
                val expandedPoints = Array(4) { Point() }
                expandedRectangle.points(expandedPoints)
                val scaled = QuadGeometry.order(expandedPoints).map { point ->
                    OcrPoint(
                        x = roundHalfToEven(point.x * scaleX)
                            .coerceIn(0, input.originalWidth).toFloat(),
                        y = roundHalfToEven(point.y * scaleY)
                            .coerceIn(0, input.originalHeight).toFloat(),
                    )
                }
                val boxWidth = hypot(
                    scaled[1].x - scaled[0].x,
                    scaled[1].y - scaled[0].y,
                )
                val boxHeight = hypot(
                    scaled[3].x - scaled[0].x,
                    scaled[3].y - scaled[0].y,
                )
                if (boxWidth > 3f && boxHeight > 3f) boxes.add(OcrBox(scaled))
            }
            boxes
        } finally {
            hierarchy.release()
            if (contourMask !== mask) contourMask.release()
            contours.forEach(Mat::release)
            mask.release()
            probability.release()
        }
    }

    private fun boxScore(probability: Mat, points: List<Point>): Float {
        if (points.isEmpty()) return 0f
        val height = probability.rows()
        val width = probability.cols()
        val minimumX = points.minOf { floor(it.x).toInt() }.coerceIn(0, width - 1)
        val maximumX = points.maxOf { ceil(it.x).toInt() }.coerceIn(0, width - 1)
        val minimumY = points.minOf { floor(it.y).toInt() }.coerceIn(0, height - 1)
        val maximumY = points.maxOf { ceil(it.y).toInt() }.coerceIn(0, height - 1)
        val mask = Mat(maximumY - minimumY + 1, maximumX - minimumX + 1, CvType.CV_8UC1, Scalar(0.0))
        val polygon = MatOfPoint().apply {
            fromList(points.map { Point(it.x - minimumX, it.y - minimumY) })
        }
        val region = probability.submat(minimumY, maximumY + 1, minimumX, maximumX + 1)
        return try {
            Imgproc.fillPoly(mask, listOf(polygon), Scalar(1.0))
            Core.mean(region, mask).`val`[0].toFloat()
        } finally {
            region.release()
            polygon.release()
            mask.release()
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

internal object QuadGeometry {
    fun order(points: Array<Point>): List<Point> {
        val sorted = points.sortedBy(Point::x)
        val topLeft: Point
        val bottomLeft: Point
        if (sorted[1].y > sorted[0].y) {
            topLeft = sorted[0]
            bottomLeft = sorted[1]
        } else {
            topLeft = sorted[1]
            bottomLeft = sorted[0]
        }
        val topRight: Point
        val bottomRight: Point
        if (sorted[3].y > sorted[2].y) {
            topRight = sorted[2]
            bottomRight = sorted[3]
        } else {
            topRight = sorted[3]
            bottomRight = sorted[2]
        }
        return listOf(topLeft, topRight, bottomRight, bottomLeft)
    }
}

internal object QuadCropper {
    private const val VERTICAL_CROP_RATIO = 1.5

    fun crop(source: Mat, box: OcrBox): Mat {
        val rectangleInput = MatOfPoint2f()
        rectangleInput.fromList(box.points.map { Point(it.x.toDouble(), it.y.toDouble()) })
        val rectangle = try {
            Imgproc.minAreaRect(rectangleInput)
        } finally {
            rectangleInput.release()
        }
        val rectanglePoints = Array(4) { Point() }
        rectangle.points(rectanglePoints)
        val ordered = QuadGeometry.order(rectanglePoints)
        val width = maxOf(
            hypot(ordered[0].x - ordered[1].x, ordered[0].y - ordered[1].y),
            hypot(ordered[2].x - ordered[3].x, ordered[2].y - ordered[3].y),
        ).toInt().coerceAtLeast(1)
        val height = maxOf(
            hypot(ordered[0].x - ordered[3].x, ordered[0].y - ordered[3].y),
            hypot(ordered[1].x - ordered[2].x, ordered[1].y - ordered[2].y),
        ).toInt().coerceAtLeast(1)
        val sourcePoints = MatOfPoint2f().apply { fromList(ordered) }
        val destinationPoints = MatOfPoint2f().apply {
            fromList(
                listOf(
                    Point(0.0, 0.0),
                    Point(width.toDouble(), 0.0),
                    Point(width.toDouble(), height.toDouble()),
                    Point(0.0, height.toDouble()),
                ),
            )
        }
        val transform = Imgproc.getPerspectiveTransform(sourcePoints, destinationPoints)
        sourcePoints.release()
        destinationPoints.release()
        val output = Mat(height, width, CvType.CV_8UC3)
        try {
            Imgproc.warpPerspective(
                source,
                output,
                transform,
                Size(width.toDouble(), height.toDouble()),
                Imgproc.INTER_CUBIC,
                Core.BORDER_REPLICATE,
            )
        } finally {
            transform.release()
        }
        if (output.rows().toDouble() / output.cols().coerceAtLeast(1) >= VERTICAL_CROP_RATIO) {
            val rotated = Mat()
            Core.rotate(output, rotated, Core.ROTATE_90_COUNTERCLOCKWISE)
            output.release()
            return rotated
        }
        return output
    }
}

internal object ReadingOrder {
    fun sort(lines: List<OcrLine>): List<OcrLine> {
        if (lines.size <= 1) return lines
        val rows = mutableListOf<Row>()
        for (line in lines.sortedBy { it.box.centerY }) {
            val current = rows.lastOrNull()
            val tolerance = current?.let {
                maxOf(10f, minOf(it.averageHeight, line.box.height) * 0.6f)
            } ?: 0f
            if (current != null && abs(current.averageCenterY - line.box.centerY) <= tolerance) {
                current.add(line)
            } else {
                rows.add(Row(mutableListOf(line)))
            }
        }
        return rows.sortedBy(Row::averageCenterY).flatMap { row ->
            val rtl = row.lines.sumOf { ScriptClassifier.arabicCount(it.text) } >
                row.lines.sumOf { ScriptClassifier.latinCount(it.text) }
            if (rtl) row.lines.sortedByDescending { it.box.centerX }
            else row.lines.sortedBy { it.box.centerX }
        }
    }

    private data class Row(val lines: MutableList<OcrLine>) {
        val averageCenterY: Float get() = lines.map { it.box.centerY }.average().toFloat()
        val averageHeight: Float get() = lines.map { it.box.height }.average().toFloat()
        fun add(line: OcrLine) { lines.add(line) }
    }
}

private object PolygonUnclip {
    private const val EPSILON = 1e-6
    private const val ARC_TOLERANCE = 0.25

    fun expand(points: List<Point>, ratio: Float): List<Point> {
        if (points.size < 3) return points
        val signedArea = signedArea(points)
        val area = abs(signedArea)
        val perimeter = perimeter(points)
        if (!area.isFinite() || !perimeter.isFinite() || area <= EPSILON || perimeter <= EPSILON) {
            return points
        }
        val distance = area * ratio / perimeter
        if (!distance.isFinite() || distance <= EPSILON) return points
        val clockwise = signedArea > 0.0
        val normals = points.indices.map { index ->
            val start = points[index]
            val end = points[(index + 1) % points.size]
            val deltaX = end.x - start.x
            val deltaY = end.y - start.y
            val length = hypot(deltaX, deltaY)
            if (!length.isFinite() || length <= EPSILON) return points
            if (clockwise) Point(deltaY / length, -deltaX / length)
            else Point(-deltaY / length, deltaX / length)
        }
        val expanded = mutableListOf<Point>()
        for (index in points.indices) {
            appendRoundJoin(
                expanded,
                points[index],
                normals[(index - 1 + normals.size) % normals.size],
                normals[index],
                distance,
                clockwise,
            )
        }
        return if (expanded.size >= 3) expanded else points
    }

    private fun appendRoundJoin(
        output: MutableList<Point>,
        center: Point,
        fromNormal: Point,
        toNormal: Point,
        distance: Double,
        clockwise: Boolean,
    ) {
        val startAngle = atan2(fromNormal.y, fromNormal.x)
        var endAngle = atan2(toNormal.y, toNormal.x)
        if (clockwise) while (endAngle < startAngle) endAngle += 2.0 * PI
        else while (endAngle > startAngle) endAngle -= 2.0 * PI
        val sweep = endAngle - startAngle
        val steps = ceil(abs(sweep) / arcStep(distance)).toInt().coerceAtLeast(1)
        for (step in 0..steps) {
            val angle = startAngle + sweep * step.toDouble() / steps
            appendUnique(
                output,
                Point(center.x + cos(angle) * distance, center.y + sin(angle) * distance),
            )
        }
    }

    private fun arcStep(distance: Double): Double {
        val ratio = (1.0 - ARC_TOLERANCE / distance).coerceIn(-1.0, 1.0)
        val step = 2.0 * acos(ratio)
        return if (step.isFinite() && step > EPSILON) step else PI / 8.0
    }

    private fun appendUnique(output: MutableList<Point>, point: Point) {
        val previous = output.lastOrNull()
        if (previous == null || hypot(point.x - previous.x, point.y - previous.y) > EPSILON) {
            output.add(point)
        }
    }

    private fun signedArea(points: List<Point>): Double = points.indices.sumOf { index ->
        val first = points[index]
        val second = points[(index + 1) % points.size]
        first.x * second.y - second.x * first.y
    } / 2.0

    private fun perimeter(points: List<Point>): Double = points.indices.sumOf { index ->
        val first = points[index]
        val second = points[(index + 1) % points.size]
        hypot(second.x - first.x, second.y - first.y)
    }
}
