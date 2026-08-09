package com.tarek.wara2a.ocr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import com.paddle.ocr.PaddleOcrException
import java.io.File

internal object InvoiceImageDecoder {
    private const val MAX_FILE_BYTES = 100L * 1024L * 1024L
    private const val MAX_DECODED_SIDE = 4096
    private const val MAX_DECODED_PIXELS = 16_000_000L

    fun decode(path: String): Bitmap {
        val file = try {
            File(path).canonicalFile
        } catch (error: Throwable) {
            throw PaddleOcrException.InvalidImage(cause = error)
        }
        if (!file.isFile || !file.canRead() || file.length() <= 0L || file.length() > MAX_FILE_BYTES) {
            throw PaddleOcrException.InvalidImage()
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw PaddleOcrException.InvalidImage()

        var sampleSize = 1
        while (
            maxOf(bounds.outWidth / sampleSize, bounds.outHeight / sampleSize) > MAX_DECODED_SIDE ||
            bounds.outWidth.toLong() * bounds.outHeight.toLong() / (sampleSize * sampleSize) > MAX_DECODED_PIXELS
        ) {
            sampleSize *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = try {
            BitmapFactory.decodeFile(file.absolutePath, options)
                ?: throw PaddleOcrException.InvalidImage()
        } catch (error: PaddleOcrException) {
            throw error
        } catch (error: OutOfMemoryError) {
            throw PaddleOcrException.InvalidImage("The invoice image is too large to decode", error)
        } catch (error: Throwable) {
            throw PaddleOcrException.InvalidImage(cause = error)
        }

        return try {
            applyExifOrientation(decoded, file)
        } catch (error: Throwable) {
            decoded.recycle()
            throw PaddleOcrException.InvalidImage("The invoice image orientation is invalid", error)
        }
    }

    @Suppress("DEPRECATION")
    private fun applyExifOrientation(bitmap: Bitmap, file: File): Bitmap {
        val orientation = runCatching {
            ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return bitmap
        }
        val oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (oriented !== bitmap) bitmap.recycle()
        return oriented
    }
}
