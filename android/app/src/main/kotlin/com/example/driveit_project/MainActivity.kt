package com.example.driveit_project

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.KeyguardManager
import android.content.Context

class MainActivity : FlutterFragmentActivity() {
    private var posterBridge: PosterBridge? = null
    private var localImportStorageBridge: LocalImportStorageBridge? = null
    private var archiveSecurityChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        posterBridge = PosterBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        localImportStorageBridge = LocalImportStorageBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        archiveSecurityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "driveit/device_archive_security").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "isIsolatedControlledRuntime") {
                    val testBuild = applicationInfo.metaData?.getBoolean("driveit.isolated_owner_runtime") == true
                    result.success(testBuild && packageName == "com.example.driveit_project.isolated_test")
                } else if (call.method != "hasSecureDeviceLock") {
                    result.notImplemented()
                } else {
                    val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    result.success(keyguard?.isDeviceSecure == true)
                }
            }
        }
    }

    @Deprecated("Delegates document picker results for poster export")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        posterBridge?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        posterBridge?.close()
        localImportStorageBridge?.close()
        archiveSecurityChannel?.setMethodCallHandler(null)
        archiveSecurityChannel = null
        super.onDestroy()
    }
}
