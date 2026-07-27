package com.meshchat.meshchat

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** Owns the Android BLE peripheral role; flutter_reactive_ble owns central links. */
@SuppressLint("MissingPermission")
class MeshGattBridge(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val METHOD_CHANNEL = "meshchat/gatt"
        const val EVENT_CHANNEL = "meshchat/gatt/inbound"
        val SERVICE_UUID: UUID = UUID.fromString("9d4f91f1-8b61-4d9e-b8b6-4c9c9f1a0001")
        val CHARACTERISTIC_UUID: UUID = UUID.fromString("9d4f91f1-8b61-4d9e-b8b6-4c9c9f1a0002")
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null

    fun register() { methodChannel.setMethodCallHandler(this); eventChannel.setStreamHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(result)
            "stop" -> { stop(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun start(result: MethodChannel.Result) {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = manager.adapter ?: run { result.error("unsupported", "Bluetooth LE is unavailable", null); return }
        if (!adapter.isEnabled) { result.error("disabled", "Enable Bluetooth to start MeshChat", null); return }
        if (gattServer != null) { result.success(null); return }
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(BluetoothGattCharacteristic(CHARACTERISTIC_UUID, BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_WRITE, BluetoothGattCharacteristic.PERMISSION_WRITE))
        gattServer = manager.openGattServer(context, callback)
        if (gattServer == null || !gattServer!!.addService(service)) { stop(); result.error("gatt", "Unable to create mesh GATT service", null); return }
        advertiser = adapter.bluetoothLeAdvertiser
        if (advertiser == null) { stop(); result.error("advertising", "BLE advertising is unavailable", null); return }
        advertiser!!.startAdvertising(AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED).setConnectable(true).build(), AdvertiseData.Builder().addServiceUuid(ParcelUuid(SERVICE_UUID)).setIncludeDeviceName(false).build(), advertiseCallback)
        result.success(null)
    }

    private val callback = object : BluetoothGattServerCallback() {
        override fun onCharacteristicWriteRequest(device: android.bluetooth.BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            if (characteristic.uuid == CHARACTERISTIC_UUID && !preparedWrite && offset == 0) {
                eventSink?.success(mapOf("peerId" to device.address, "payload" to Base64.encodeToString(value, Base64.NO_WRAP)))
            }
            if (responseNeeded) gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {}
    private fun stop() { advertiser?.stopAdvertising(advertiseCallback); advertiser = null; gattServer?.close(); gattServer = null }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }
}
