import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val isReleaseTask = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (isReleaseTask && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Missing app/android/key.properties for release signing. " +
            "Create it before running release builds."
    )
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val baseVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val wearVersionCode = (baseVersionCode * 1000) + 1
val wearVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0.0"

android {
    namespace = "com.brensch.lift.wear"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.brensch.lift"
        minSdk = 30
        targetSdk = 36
        versionCode = wearVersionCode
        versionName = wearVersionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val configuredStoreFile = keystoreProperties["storeFile"] as String
                storeFile = rootProject.file(configuredStoreFile)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        compose = true
    }

    sourceSets {
        getByName("main") {
            java.srcDir("../shared-proto/src/main/java")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.fragment:fragment-ktx:1.8.6")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")

    implementation("androidx.wear.compose:compose-material:1.4.1")
    implementation("androidx.wear.compose:compose-foundation:1.4.1")
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    implementation("androidx.wear:wear:1.3.0")
    implementation("androidx.health:health-services-client:1.1.0-beta01")

    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.8.1")
    implementation("com.google.protobuf:protobuf-javalite:4.30.2")
}
