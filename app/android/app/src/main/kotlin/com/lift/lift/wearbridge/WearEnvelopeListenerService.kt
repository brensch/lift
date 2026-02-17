package com.lift.lift.wearbridge

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearEnvelopeListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        WearBridgeManager.onWearEnvelopeReceived(messageEvent.path, messageEvent.data)
        super.onMessageReceived(messageEvent)
    }
}
