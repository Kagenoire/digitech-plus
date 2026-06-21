package com.digitech.digitech_plus

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.digitech/cookies"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: ""
                    val cookieManager = android.webkit.CookieManager.getInstance()
                    result.success(cookieManager.getCookie(url))
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "clearCookies" -> {
                    val cookieManager = android.webkit.CookieManager.getInstance()
                    cookieManager.removeAllCookies(null)
                    cookieManager.flush()
                    result.success(null)
                }
                "requestBatteryExemption" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        // Fallback: open general battery optimization settings
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
