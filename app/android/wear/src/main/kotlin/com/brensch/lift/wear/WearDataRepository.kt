package com.brensch.lift.wear

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import workout.v1.Wearable

object WearDataRepository {
    private val _snapshot = MutableStateFlow<Wearable.WearWorkoutSnapshot?>(null)
    val snapshot: StateFlow<Wearable.WearWorkoutSnapshot?> = _snapshot.asStateFlow()

    fun updateSnapshot(snapshot: Wearable.WearWorkoutSnapshot) {
        _snapshot.value = snapshot
    }
}
