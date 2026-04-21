package com.protean.edly

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "edly/media"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePngToPictures" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (fileName.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Missing fileName or bytes.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(savePngToPictures(fileName, bytes))
                    } catch (error: Exception) {
                        result.error(
                            "SAVE_FAILED",
                            error.message ?: "Could not save QR image.",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePngToPictures(fileName: String, bytes: ByteArray): String {
        val safeFileName = if (fileName.endsWith(".png", ignoreCase = true)) {
            fileName
        } else {
            "$fileName.png"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, safeFileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Edly"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Cannot create media entry.")

            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Cannot open media output stream.")

            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            return uri.toString()
        }

        val directory = File(
            getExternalFilesDir(Environment.DIRECTORY_PICTURES),
            "Edly"
        )
        if (!directory.exists()) {
            directory.mkdirs()
        }

        val file = File(directory, safeFileName)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(file.absolutePath),
            arrayOf("image/png"),
            null
        )

        return file.absolutePath
    }
}
