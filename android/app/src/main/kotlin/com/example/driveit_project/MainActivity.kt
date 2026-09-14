package com.example.driveit_project

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var posterBridge: PosterBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        posterBridge = PosterBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Delegates document picker results for poster export")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        posterBridge?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        posterBridge?.close()
        super.onDestroy()
    }
}
