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

fun readEnv(key: String): String = if (dotenvFile.exists()) {
    dotenvFile.readLines()
        .map { it.trim() }
        .firstOrNull { it.startsWith("$key=") }
        ?.substringAfter("=")
        ?.trim()
        ?.trim('"', '\'')
        ?: ""
} else {
    ""
}

val mapsApiKey: String = readEnv("MAPS_API_KEY")

// 개발용 기능 플래그 (이슈 #109).
//
// **인앱 업데이트(#104)를 통째로 넣고 뺀다.** 스토어 배포 전까지는
// 사이드로드가 유일한 배포 경로라 그 기능이 필요하지만, Play 는
// `REQUEST_INSTALL_PACKAGES` 를 앱스토어·파일 관리자가 아닌 앱에서
// 거의 반려한다.
//
// **Dart 쪽 화면만 숨기는 것으로는 부족하다.** 권한 선언이 매니페스트에
// 남아 있으면 심사에 그대로 걸린다. 그래서 이 값이 매니페스트 병합
// (`tools:node`)과 BuildConfig 양쪽을 함께 제어한다.
//
// **기본값은 꺼짐이다.** `.env` 가 없는 사람이 빌드하면 심사 가능한
// 형태로 나오는 것이 안전하다 — 실수로 켜진 채 제출되는 것이 그 반대보다
// 훨씬 비싸다.
val devFlag: Boolean = readEnv("DEV_FLAG").equals("true", ignoreCase = true)

android {

    // BuildConfig.DEV_FLAG 를 쓰기 위해 필요하다 (이슈 #109)
    buildFeatures {
        buildConfig = true
    }

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

        // 설치 권한을 넣고 뺀다 (이슈 #109).
        //
        // 꺼진 경우 **이미 선언된 INTERNET 으로 치환한다.** 병합기가 중복
        // 선언을 하나로 합치므로 결과 매니페스트에 설치 권한이 남지 않는다.
        //
        // `tools:node` 에 placeholder 를 쓰는 방법은 불가능하다 — 병합기가
        // 치환보다 먼저 그 값을 파싱해 `No enum constant` 로 죽는다.
        manifestPlaceholders["installPermission"] = if (devFlag) {
            "android.permission.REQUEST_INSTALL_PACKAGES"
        } else {
            "android.permission.INTERNET"
        }

        // Dart 가 채널로 읽어 설정 화면 항목을 감춘다
        buildConfigField("boolean", "DEV_FLAG", devFlag.toString())
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

    // 지오펜스·정밀 위치를 앱이 직접 다룬다 (이슈 #93).
    // native_geofence 가 transitive 로 가져오지만, 우리 코드가 직접 쓰는
    // 이상 명시한다 — 그 패키지 의존을 걷어낼 때 조용히 깨지면 안 된다.
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
