plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties file
import java.util.Properties
import java.io.FileInputStream
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Google Maps API 키 (docs/08-OPERATIONS.md).
//
// 단일 소스는 레포 루트의 .env 다 — 커밋되지 않으며, CI 는 Secret 으로 만든다.
// 파일이 없거나 값이 비어 있어도 빌드는 성공한다. 지도만 회색으로 뜨고
// 나머지 기능은 정상 동작한다 — 키가 없는 사람도 빌드할 수 있어야 한다.
val dotenvFile = rootProject.file("../.env")
val mapsApiKey: String = if (dotenvFile.exists()) {
    dotenvFile.readLines()
        .map { it.trim() }
        .firstOrNull { it.startsWith("MAPS_API_KEY=") }
        ?.substringAfter("=")
        ?.trim()
        ?.trim('"', '\'')
        ?: ""
} else {
    ""
}

android {

    // Signing Configurations
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    namespace = "kr.suhsaechan.ear_loc_alert"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications 가 요구한다 (#57).
        // 최소 지원이 Android 8.0(API 26)이라 최신 java.time API 를
        // 구버전에서 쓰려면 desugaring 이 필요하다.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "kr.suhsaechan.ear_loc_alert"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // docs/01-REQUIREMENTS.md 4.4 — Android 8.0 이상
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest 의 ${MAPS_API_KEY} 를 치환한다.
        // 키를 매니페스트에 직접 적지 않는 이유는 커밋을 막기 위해서다.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // core library desugaring — flutter_local_notifications 요구 (#57)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
