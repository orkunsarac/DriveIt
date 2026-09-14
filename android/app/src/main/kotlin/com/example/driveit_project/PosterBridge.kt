package com.example.driveit_project

import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.location.Geocoder
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.concurrent.Executors

/** Poster-only export and optional place lookup. No drive-service dependency. */
class PosterBridge(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private const val TAG = "DriveItPosterBridge"
    }

    private val channel = MethodChannel(messenger, "driveit/posters")
    private val worker = Executors.newFixedThreadPool(2)
    private var pending: MethodChannel.Result? = null
    private var source: File? = null
    private val requestCode = 7341

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "savePng" -> {
                    openDocument(call.argument<String>("path"), call.argument<String>("name"), result)
                }
                "saveToGallery" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        openDocument(call.argument<String>("path"), call.argument<String>("name"), result)
                    } else {
                        val file = posterFile(call.argument<String>("path"), result) ?: return@setMethodCallHandler
                        val name = safeName(call.argument<String>("name"))
                        Log.d(TAG, "gallery.start path=${file.path} bytes=${file.length()} name=$name")
                        worker.execute {
                            val resolver = activity.contentResolver
                            val values = ContentValues().apply {
                                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/DriveIt")
                                put(MediaStore.Images.Media.IS_PENDING, 1)
                            }
                            val uri = resolver.insert(
                                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                                values,
                            )
                            try {
                                require(uri != null) { "MediaStore insert returned null" }
                                Log.d(TAG, "gallery.insert.done uri=$uri")
                                var copiedBytes = 0L
                                resolver.openOutputStream(uri)?.use { output ->
                                    file.inputStream().use { input -> copiedBytes = input.copyTo(output) }
                                } ?: error("No output stream")
                                require(copiedBytes > 0) { "No PNG bytes were written to MediaStore" }
                                Log.d(TAG, "gallery.bytes.done uri=$uri bytes=$copiedBytes")
                                values.clear()
                                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                                val updated = resolver.update(uri, values, null, null)
                                require(updated > 0) { "MediaStore item could not be finalized" }
                                Log.d(TAG, "gallery.complete uri=$uri finalized=$updated")
                                activity.runOnUiThread { result.success(uri.toString()) }
                            } catch (error: Exception) {
                                Log.e(TAG, "gallery.failed path=${file.path} uri=$uri", error)
                                if (uri != null) resolver.delete(uri, null, null)
                                activity.runOnUiThread {
                                    result.error("gallery", "Poster galeriye kaydedilemedi.", error.javaClass.simpleName)
                                }
                            }
                        }
                    }
                }
                "sharePng" -> {
                    val file = posterFile(call.argument<String>("path"), result) ?: return@setMethodCallHandler
                    try {
                        val uri = FileProvider.getUriForFile(
                            activity,
                            "${activity.packageName}.poster_files",
                            file,
                        )
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri("DriveIt poster", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        Log.d(TAG, "share.start path=${file.path} uri=$uri")
                        activity.startActivity(Intent.createChooser(intent, "DriveIt posterini paylaş"))
                        result.success(null)
                    } catch (error: Exception) {
                        Log.e(TAG, "share.failed path=${call.argument<String>("path")}", error)
                        result.error("share", "Poster paylaşım ekranı açılamadı.", error.javaClass.simpleName)
                    }
                }
                "endpointNames" -> {
                    val coords = listOf("startLat", "startLng", "endLat", "endLng").map { call.argument<Number>(it)?.toDouble() }
                    if (coords.any { it == null || !it.isFinite() }) {
                        result.success(emptyMap<String, String>())
                    } else {
                        worker.execute {
                            val names = mutableMapOf<String, String>()
                            if (Geocoder.isPresent()) {
                                val coder = Geocoder(activity.applicationContext, Locale.getDefault())
                                for ((key, index) in listOf("start" to 0, "end" to 2)) {
                                    try {
                                        @Suppress("DEPRECATION")
                                        val address = coder.getFromLocation(coords[index]!!, coords[index + 1]!!, 1)?.firstOrNull()
                                        val name = address?.let { listOfNotNull(it.thoroughfare ?: it.subLocality, it.locality ?: it.subAdminArea).distinct().joinToString(", ") }
                                        if (!name.isNullOrBlank()) names[key] = name
                                    } catch (_: Exception) { /* Coordinate fallback in Flutter. */ }
                                }
                            }
                            activity.runOnUiThread { result.success(names) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun safeName(value: String?): String {
        val raw = value ?: "DriveIt.png"
        val clean = raw.replace(Regex("[^A-Za-z0-9._-]"), "-")
        return if (clean.endsWith(".png", ignoreCase = true)) clean else "$clean.png"
    }

    private fun posterFile(path: String?, result: MethodChannel.Result): File? {
        return try {
            val file = File(path ?: error("Missing path")).canonicalFile
            val root = File(activity.applicationInfo.dataDir).canonicalPath + File.separator
            require(file.path.startsWith(root)) { "Poster is outside app-private storage" }
            require(file.isFile && file.length() > 0) { "Poster file is missing or empty" }
            require(file.extension.equals("png", true)) { "Poster is not a PNG file" }
            file
        } catch (error: Exception) {
            Log.e(TAG, "posterFile.invalid path=$path", error)
            result.error("poster_file", "Poster dosyası kullanılamıyor.", error.javaClass.simpleName)
            null
        }
    }

    private fun openDocument(path: String?, name: String?, result: MethodChannel.Result) {
                    if (pending != null) {
                        result.error("busy", "Bir dosya kaydetme işlemi devam ediyor.", null)
                    } else {
                        try {
                            val file = posterFile(path, result) ?: return
                            pending = result
                            source = file
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/png"
                                putExtra(Intent.EXTRA_TITLE, safeName(name))
                            }
                            activity.startActivityForResult(intent, requestCode)
                        } catch (error: Exception) {
                            Log.e(TAG, "document.open.failed path=$path", error)
                            pending = null
                            source = null
                            result.error("export", "Dosya kaydetme ekranı açılamadı.", error.javaClass.simpleName)
                        }
                    }
    }

    fun onActivityResult(code: Int, status: Int, data: Intent?) {
        if (code != requestCode) return
        val result = pending ?: return
        val file = source
        pending = null
        source = null
        val uri = data?.data
        if (status != Activity.RESULT_OK || uri == null || file == null) {
            result.success(false)
            return
        }
        worker.execute {
            try {
                val stream = activity.contentResolver.openOutputStream(uri) ?: error("No output stream")
                var copiedBytes = 0L
                stream.use { output ->
                    file.inputStream().use { input -> copiedBytes = input.copyTo(output) }
                }
                require(copiedBytes > 0) { "No PNG bytes were written" }
                Log.d(TAG, "document.complete uri=$uri bytes=$copiedBytes")
                activity.runOnUiThread { result.success(uri.toString()) }
            } catch (error: Exception) {
                Log.e(TAG, "document.failed uri=$uri path=${file.path}", error)
                activity.runOnUiThread {
                    result.error("export", "PNG dosyası yazılamadı.", error.javaClass.simpleName)
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        pending?.success(false)
        pending = null
        worker.shutdown()
    }
}
