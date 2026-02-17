package com.brensch.lift.wear

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import workout.v1.Wearable

class PhoneMessageListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != WearTransport.PHONE_TO_WEAR_PATH) {
            super.onMessageReceived(messageEvent)
            return
        }

        runCatching {
            val envelope = Wearable.PhoneToWearEnvelope.parseFrom(messageEvent.data)
            if (envelope.hasSnapshot()) {
                WearDataRepository.updateSnapshot(envelope.snapshot)
            }
        }
    }
}
