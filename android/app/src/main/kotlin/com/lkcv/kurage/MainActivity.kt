package com.lkcv.kurage

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kurage/window_insets")
            .setMethodCallHandler { call, result ->
                if (call.method != "cutoutTop") {
                    result.notImplemented()
                } else {
                    val insets = window.decorView.rootWindowInsets
                    val top = if (insets == null) null
                        else if (Build.VERSION.SDK_INT >= 30)
                            insets.getInsetsIgnoringVisibility(android.view.WindowInsets.Type.displayCutout()).top
                        else if (Build.VERSION.SDK_INT >= 28)
                            insets.displayCutout?.safeInsetTop ?: 0
                        else 0
                    result.success(top)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kurage/download_background")
            .setMethodCallHandler { call, result ->
                val intent = Intent(applicationContext, DownloadForegroundService::class.java)
                try {
                    when (call.method) {
                        "start" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                applicationContext.startForegroundService(intent)
                            } else {
                                applicationContext.startService(intent)
                            }
                            result.success(true)
                        }
                        "stop" -> {
                            applicationContext.stopService(intent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("FOREGROUND_SERVICE", error.message, null)
                }
            }
    }
}
