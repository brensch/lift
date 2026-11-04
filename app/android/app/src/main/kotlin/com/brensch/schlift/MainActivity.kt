package com.brensch.schlift

import androidx.activity.result.contract.ActivityResultContracts
import com.brensch.schlift.wearbridge.WearBridgeManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    // / A file waiting for the person to pick where it's saved: its path, and
    // / who to tell how it went.
    private var pendingSave: Pair<String, MethodChannel.Result>? = null

    // / The system's "save as" picker: the person picks a place (Downloads,
    // / a drive) and the file is copied there.
    private val createDocument =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/gzip")) { uri ->
            val (path, result) = pendingSave ?: return@registerForActivityResult
            pendingSave = null
            if (uri == null) {
                result.success(false)
                return@registerForActivityResult
            }
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    withContext(Dispatchers.IO) {
                        contentResolver.openOutputStream(uri).use { out ->
                            requireNotNull(out) { "the picked place can't be written" }
                            File(path).inputStream().use { it.copyTo(out) }
                        }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Save a file the app made where the person chooses: true when
        // saved, false when they backed out.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "schlift/files",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveAs" -> {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name")
                    if (path == null || name == null) {
                        result.error("invalid_args", "Missing path or name", null)
                        return@setMethodCallHandler
                    }
                    pendingSave?.second?.success(false)
                    pendingSave = path to result
                    createDocument.launch(name)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "schlift/wear_bridge/methods",
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

                "getWatchClockSync" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(WearBridgeManager.requestWatchClockSync(this@MainActivity))
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "schlift/wear_bridge/intents",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    WearBridgeManager.setIntentSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    WearBridgeManager.setIntentSink(null)
                }
            },
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "schlift/wear_bridge/sensors",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    WearBridgeManager.setSensorSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    WearBridgeManager.setSensorSink(null)
                }
            },
        )
    }
}
