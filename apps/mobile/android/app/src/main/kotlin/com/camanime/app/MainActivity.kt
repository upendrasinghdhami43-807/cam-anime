package com.camanime.app

import com.camanime.engine.bridge.CamAnimePlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity is a LifecycleOwner, which CameraX needs to bind the camera.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(CamAnimePlugin())
    }
}
