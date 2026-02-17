package com.lift.lift.wearbridge

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearEnvelopeListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d("LiftWearBridge", "Message received path=${messageEvent.path} size=${messageEvent.data.size}")
        WearBridgeManager.onWearEnvelopeReceived(messageEvent.path, messageEvent.data)
        super.onMessageReceived(messageEvent)
    }
}
