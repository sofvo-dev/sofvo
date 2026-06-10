package com.sofvo.app

import android.content.Context
import android.os.RemoteException
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sofvo.app/install_referrer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstallReferrer") {
                getInstallReferrer(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getInstallReferrer(result: MethodChannel.Result) {
        val prefs = getSharedPreferences("sofvo_prefs", Context.MODE_PRIVATE)
        // 初回インストール時のみ処理（2回目以降はスキップ）
        if (prefs.getBoolean("referrer_checked", false)) {
            result.success(null)
            return
        }
        prefs.edit().putBoolean("referrer_checked", true).apply()

        val client = InstallReferrerClient.newBuilder(this).build()
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                    try {
                        val referrer = client.installReferrer.installReferrer
                        client.endConnection()
                        result.success(referrer)
                    } catch (e: RemoteException) {
                        result.success(null)
                    }
                } else {
                    result.success(null)
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                result.success(null)
            }
        })
    }
}
