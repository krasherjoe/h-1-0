package com.example.h_1

import android.accounts.AccountManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.h_1/device_accounts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getGoogleAccounts") {
                    try {
                        val am = AccountManager.get(this)
                        val accounts = am.getAccountsByType("com.google")
                        val emails = accounts.map { it.name }
                        result.success(emails)
                    } catch (e: Exception) {
                        result.error("ACCOUNT_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
