package com.brensch.schlift.wearbridge

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearEnvelopeListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d("SchliftWearBridge", "Message received path=${messageEvent.path} size=${messageEvent.data.size}")
        WearBridgeManager.onWearMessageReceived(
            this,
            messageEvent.sourceNodeId,
            messageEvent.path,
            messageEvent.data,
        )
        super.onMessageReceived(messageEvent)
    }
}
