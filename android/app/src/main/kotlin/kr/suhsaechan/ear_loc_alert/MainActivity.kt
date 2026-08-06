package kr.suhsaechan.ear_loc_alert

import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 잠금화면 위에 뜨고 화면을 깨운다 (이슈 #74).
        //
        // 전체화면 알림(FSI)이 이 액티비티를 띄우는 경로에서 필요하다 —
        // 이것이 없으면 잠긴 화면 뒤에서 조용히 실행만 되고 사용자는 아무것도
        // 보지 못한다. API 27 미만은 매니페스트 속성도 이 API 도 없어 그냥
        // 넘어간다(알림과 진동으로 성립한다).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

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

        // 전체화면 알림 권한 (이슈 #74).
        // permission_handler 가 다루지 않아 직접 읽고 설정 화면으로 보낸다.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kr.suhsaechan.ear_loc_alert/alert_reliability",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                "openFullScreenIntentSettings" -> {
                    openFullScreenIntentSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 감시 서비스 제어 (이슈 #74)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kr.suhsaechan.ear_loc_alert/alert_window",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startWatch" -> {
                    sendToWatchService(AlertWatchService.ACTION_START_WATCH)
                    result.success(null)
                }
                "stopWatch" -> {
                    sendToWatchService(AlertWatchService.ACTION_STOP_WATCH)
                    result.success(null)
                }
                "stopAlert" -> {
                    sendToWatchService(AlertWatchService.ACTION_STOP_ALERT)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Android 14+ 는 알람·통화 계열이 아닌 앱에 전체화면 알림 권한을 자동으로
     * 주지 않는다. 그 이전 버전은 매니페스트 선언만으로 부여되므로 true 다
     * (docs/10-DECISIONS.md 006 재검토).
     */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(NotificationManager::class.java) ?: return true
        return manager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (error: Exception) {
            // 기기가 이 설정 화면을 갖고 있지 않다 — 앱 설정으로 떨어진다
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"),
                    ),
                )
            } catch (fallbackError: Exception) {
                // 설정을 못 열어도 온보딩은 계속된다
            }
        }
    }

    private fun sendToWatchService(action: String) {
        val intent = Intent(this, AlertWatchService::class.java).setAction(action)
        try {
            if (action == AlertWatchService.ACTION_START_WATCH) {
                startForegroundService(intent)
            } else {
                // 이미 떠 있는 서비스에 보내는 신호다 — 새로 띄우지 않는다
                startService(intent)
            }
        } catch (error: Exception) {
            // 서비스를 못 띄워도 앱은 동작한다 — 알림이 약해질 뿐이다
        }
    }
}
