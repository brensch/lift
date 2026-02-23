package com.brensch.lift

import com.brensch.lift.wearbridge.WearBridgeManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lift/wear_bridge/methods",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishSnapshot" -> {
                    val payload = call.argument<ByteArray>("payload")
                    if (payload == null) {
                        result.error("invalid_args", "Missing payload", null)
                        return@setMethodCallHandler
                    }
                    WearBridgeManager.publishSnapshot(this, payload)
                    result.success(null)
                }
                "openWatchApp" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        val sent = WearBridgeManager.requestWatchAppOpen(this@MainActivity)
                        result.success(sent > 0)
                    }
                }
                "isWatchAppAvailable" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(WearBridgeManager.isWatchAppAvailable(this@MainActivity))
                    }
                }
                "isWatchAppOpenOnWatch" -> {
                    result.success(WearBridgeManager.isWatchAppOpenOnWatch())
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lift/wear_bridge/intents",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                WearBridgeManager.setIntentSink(events)
            }

            override fun onCancel(arguments: Any?) {
                WearBridgeManager.setIntentSink(null)
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lift/wear_bridge/sensors",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                WearBridgeManager.setSensorSink(events)
            }

            override fun onCancel(arguments: Any?) {
                WearBridgeManager.setSensorSink(null)
            }
        })
    }
}
