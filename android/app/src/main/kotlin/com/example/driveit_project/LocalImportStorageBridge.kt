package com.example.driveit_project

import android.content.Context
import android.os.StatFs
import android.system.Os
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Read capacity / sync app-private directories only. No file copy, migration,
 * Auth or GPS activity is started by registering this channel. */
class LocalImportStorageBridge(context: Context, messenger: BinaryMessenger) {
    private val root = File(context.applicationInfo.dataDir).canonicalFile
    private val channel = MethodChannel(messenger, "driveit/local_import_storage")
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                val requested = File(call.argument<String>("path") ?: error("path required")).canonicalFile
                require(requested.path.startsWith(root.path + File.separator))
                when (call.method) {
                    "availableBytes" -> {
                        var existing = requested
                        while (!existing.exists()) existing = existing.parentFile ?: error("no parent")
                        require(existing.path == root.path || existing.path.startsWith(root.path + File.separator))
                        result.success(StatFs(existing.path).availableBytes)
                    }
                    "syncDirectory" -> {
                        require(requested.isDirectory)
                        // O_DIRECTORY is not exposed by this Android public SDK.
                        // Verify the opened descriptor rather than hardcoding a
                        // Linux flag or relying only on the earlier path check.
                        val fd = Os.open(requested.path, OsConstants.O_RDONLY, 0)
                        try {
                            require(OsConstants.S_ISDIR(Os.fstat(fd).st_mode))
                            Os.fsync(fd)
                        } finally { Os.close(fd) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                // Do not return raw paths, SQL, user data or exception messages.
                result.error("local_import_storage_unavailable", "Private storage check failed", null)
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null) }
}
