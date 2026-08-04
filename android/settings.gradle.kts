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
    id("com.android.application") version "8.9.1" apply false
    // google_maps_flutter 의 Android 구현이 Kotlin 2.2 메타데이터를 쓴다 —
    // 2.1.0 이면 assembleDebug 가 "newer version of the Kotlin Gradle plugin" 으로 실패한다 (#70)
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
