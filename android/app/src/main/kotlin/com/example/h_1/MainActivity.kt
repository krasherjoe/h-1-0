package com.example.h_1

import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.h_1/device_accounts"
    private val REQUEST_PICK_ACCOUNT = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickGoogleAccount" -> {
                        pendingResult = result
                        @Suppress("DEPRECATION")
                        val intent = AccountManager.newChooseAccountIntent(
                            null, null,
                            arrayOf("com.google"),
                            null, null, null, null
                        )
                        startActivityForResult(intent, REQUEST_PICK_ACCOUNT)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_ACCOUNT) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val email = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                pendingResult?.success(email)
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}
