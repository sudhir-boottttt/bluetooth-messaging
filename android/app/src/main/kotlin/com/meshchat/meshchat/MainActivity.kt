package com.meshchat.meshchat

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Android entry point and runtime nearby-device permission owner. */
class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MeshGattBridge(this, flutterEngine.dartExecutor.binaryMessenger).register()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meshchat/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestBlePermissions") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE)
                } else {
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                }
                if (permissions.all { ActivityCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }) {
                    result.success(true)
                } else {
                    permissionResult = result
                    ActivityCompat.requestPermissions(this, permissions, 742)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 742) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            permissionResult = null
        }
    }
}
