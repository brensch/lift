package com.brensch.schlift.appicon

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

// / The "App icon" setting on Android. The launcher has no way to be handed
// / another icon, so the manifest declares a launcher entry per icon (the
// / Icon* activity-aliases, all opening MainActivity) and this enables the
// / one asked for and disables the rest. Dart asks over "schlift/app_icon"
// / (`lib/services/app_icon.dart`); the iPhone's is
// / `ios/Runner/AppIconPlugin.swift`.
object AppIcon {
    // / The setting's names, and the alias each enables. "ready", the
    // / orange icon, is the default.
    private val aliases =
        mapOf(
            "ready" to "IconReady",
            "lifting" to "IconLifting",
            "resting" to "IconResting",
            "yapping" to "IconYapping",
        )

    // The aliases are declared in the manifest's namespace, whatever the
    // installed package is called (the debug app has a suffix).
    private fun component(
        context: Context,
        alias: String,
    ) = ComponentName(context.packageName, "com.brensch.schlift.$alias")

    // / The icon on show: the alias that is enabled.
    fun current(context: Context): String {
        val packages = context.packageManager
        for ((name, alias) in aliases) {
            val state = packages.getComponentEnabledSetting(component(context, alias))
            val enabled =
                state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                    (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && name == "ready")
            if (enabled) return name
        }
        return "ready"
    }

    // / Show `name`'s icon. False for a name there is no icon for. The one
    // / wanted is enabled before the others are disabled, so the app is never
    // / without a launcher entry.
    fun set(
        context: Context,
        name: String,
    ): Boolean {
        val wanted = aliases[name] ?: return false
        val packages = context.packageManager
        packages.setComponentEnabledSetting(
            component(context, wanted),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (alias in aliases.values) {
            if (alias == wanted) continue
            packages.setComponentEnabledSetting(
                component(context, alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        return true
    }
}
