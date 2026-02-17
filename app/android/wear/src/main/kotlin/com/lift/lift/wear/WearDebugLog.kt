package com.lift.lift.wear

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object WearDebugLog {
    private const val MAX_LINES = 40
    private val formatter = SimpleDateFormat("HH:mm:ss", Locale.US)
    private val _lines = MutableStateFlow<List<String>>(emptyList())
    val lines: StateFlow<List<String>> = _lines.asStateFlow()

    fun add(message: String) {
        val ts = formatter.format(Date())
        val line = "$ts $message"
        val next = (_lines.value + line).takeLast(MAX_LINES)
        _lines.value = next
    }

    fun addLong(message: String, chunkSize: Int = 42) {
        if (message.isEmpty()) {
            add("")
            return
        }
        var index = 0
        while (index < message.length) {
            val end = (index + chunkSize).coerceAtMost(message.length)
            add(message.substring(index, end))
            index = end
        }
    }
}
