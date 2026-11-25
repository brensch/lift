pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.3.1" apply false
    // Declared so KGP stays on the buildscript classpath (it aligns
    // org.jetbrains:annotations for AGP); modules do NOT apply it — AGP 9's
    // Built-in Kotlin compiles the app. The Compose compiler plugin follows.
    id("org.jetbrains.kotlin.android") version "2.4.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.21" apply false
}

include(":app")

val includeWearModule =
    gradle.startParameter.taskNames.any { task ->
        task.contains("wear", ignoreCase = true)
    }
if (includeWearModule) {
    include(":wear")
}
