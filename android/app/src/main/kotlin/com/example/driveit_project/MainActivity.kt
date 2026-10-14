package com.example.driveit_project

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.KeyguardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log

class MainActivity : FlutterFragmentActivity() {
    private var posterBridge: PosterBridge? = null
    private var localImportStorageBridge: LocalImportStorageBridge? = null
    private var archiveSecurityChannel: MethodChannel? = null
    private var archiveActivityResumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        posterBridge = PosterBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        localImportStorageBridge = LocalImportStorageBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        archiveSecurityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "driveit/device_archive_security").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "isIsolatedControlledRuntime") {
                    val expectedPackage = "com.example.driveit_project.isolated_test"
                    val markerKey = "driveit.isolated_owner_runtime"
                    val isolatedPackage = packageName == expectedPackage
                    // Context.applicationInfo is not guaranteed to include
                    // manifest metadata. Request GET_META_DATA explicitly;
                    // otherwise a valid application-level marker can appear
                    // absent and the release-only test runtime fails closed.
                    @Suppress("DEPRECATION")
                    val flaggedApplicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                        )
                    } else {
                        packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    }
                    val markerValue = flaggedApplicationInfo.metaData?.get(markerKey)
                    // The merged APK manifest declares an Android boolean.
                    // Do not accept string or truthy representations.
                    val markerEnabled = markerValue == true
                    if (isolatedPackage) {
                        val valueLabel = when (markerValue) {
                            true -> "true"
                            false -> "false"
                            null -> "<missing>"
                            else -> "<unexpected>"
                        }
                        val reason = when {
                            markerValue == null -> "metadata_missing"
                            markerValue !is Boolean -> "metadata_wrong_type"
                            !markerEnabled -> "marker_false"
                            else -> "accepted"
                        }
                        Log.i(
                            "DriveItIsolatedGuard",
                            "applicationId=$packageName component=${componentName.className} " +
                                "metadataSource=PackageManager.GET_META_DATA expectedKey=$markerKey " +
                                "markerValue=$valueLabel markerType=${markerValue?.javaClass?.name ?: "<missing>"} " +
                                "reason=$reason",
                        )
                    }
                    result.success(markerEnabled && isolatedPackage)
                } else if (call.method == "isLocalProductionOwnerRuntime") {
                    val expectedPackage = "com.example.driveit_project"
                    val packageMatches = packageName == expectedPackage
                    @Suppress("DEPRECATION")
                    val flaggedApplicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                        )
                    } else {
                        packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    }
                    val metadata = flaggedApplicationInfo.metaData
                    val localMarker = metadata?.get("driveit.local_owner_runtime")
                    val isolatedMarker = metadata?.get("driveit.isolated_owner_runtime")
                    // Both markers are Android booleans. The normal package
                    // must carry the explicit local opt-in and must not be an
                    // isolated test composition.
                    result.success(
                        packageMatches && localMarker == true && isolatedMarker == false,
                    )
                } else if (call.method == "getArchiveHostState" &&
                    packageName == "com.example.driveit_project.isolated_test") {
                    result.success(mapOf(
                        "applicationId" to packageName,
                        "activity" to componentName.className,
                        "activityResumed" to archiveActivityResumed,
                        "windowFocus" to window?.decorView?.hasWindowFocus(),
                        "taskRoot" to isTaskRoot,
                    ))
                } else if (call.method == "isDeviceArchiveRuntimeAllowed") {
                    @Suppress("DEPRECATION")
                    val flaggedApplicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                        )
                    } else {
                        packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    }
                    val metadata = flaggedApplicationInfo.metaData
                    val isolatedMarker = metadata?.get("driveit.isolated_owner_runtime")
                    val localMarker = metadata?.get("driveit.local_owner_runtime")
                    val allowedProduction = packageName == "com.example.driveit_project" &&
                        localMarker == true && isolatedMarker == false
                    val allowedIsolatedAcceptance = packageName == "com.example.driveit_project.isolated_test" &&
                        isolatedMarker == true && localMarker == false
                    result.success(allowedProduction || allowedIsolatedAcceptance)
                } else if (call.method != "hasSecureDeviceLock") {
                    result.notImplemented()
                } else {
                    val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    result.success(keyguard?.isDeviceSecure == true)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        archiveActivityResumed = true
    }

    override fun onPause() {
        archiveActivityResumed = false
        super.onPause()
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
