package kr.suhsaechan.ear_loc_alert

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Google Maps API 키를 Dart(장소 검색 REST)에 넘긴다.
        // 키의 단일 소스는 .env → 매니페스트 주입이고, 여기서는 그 값을
        // 도로 읽기만 한다 (docs/08-OPERATIONS.md). 키 없이 빌드되면 빈
        // 문자열이 가고, Dart 쪽이 검색을 조용히 비활성화한다.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kr.suhsaechan.ear_loc_alert/maps_api_key",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getMapsApiKey") {
                val info = packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.GET_META_DATA,
                )
                result.success(
                    info.metaData?.getString("com.google.android.geo.API_KEY") ?: "",
                )
            } else {
                result.notImplemented()
            }
        }
    }
}
