package kr.suhsaechan.ear_loc_alert

import android.app.NotificationManager
import android.content.Intent
import android.media.AudioManager
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

        // 시스템 미디어 볼륨 제어 (이슈 #86).
        //
        // 시스템 볼륨이 0 이면 앱 재생 볼륨을 아무리 올려도 무음이다.
        // 알림 시점에 설정값 수준까지 올리고, 해제되면 되돌린다.
        // 여기서 소리를 내지는 않는다 — 재생 판정은 Dart 에만 있다
        // (docs/10-DECISIONS.md 019). 이 채널이 하는 것은 볼륨 숫자 조정뿐이다.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kr.suhsaechan.ear_loc_alert/system_volume",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "raiseSystemVolume" -> {
                    raiseSystemVolume(call.argument<Double>("fraction") ?: 0.0)
                    result.success(null)
                }
                "restoreSystemVolume" -> {
                    restoreSystemVolume()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 현재 위치 1회 조회 (이슈 #98).
        //
        // 지도의 "내 위치" 버튼을 직접 만들기 위해 필요하다. SDK 기본 버튼은
        // 우상단 고정이라 상태 알약에 가려 잘려 보였다.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kr.suhsaechan.ear_loc_alert/current_location",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getCurrentLocation") {
                CurrentLocationProvider(this).fetch { location ->
                    if (location == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf("latitude" to location.first, "longitude" to location.second),
                        )
                    }
                }
            } else {
                result.notImplemented()
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
                // 지오펜스 등록 (이슈 #93).
                //
                // 등록 주체가 서비스인 이유는 **앱이 죽어도 등록이 살아있어야**
                // 하기 때문이다. 액티비티가 소유하면 프로세스 회수와 함께 사라진다.
                "syncGeofences" -> {
                    val fences = call.argument<List<Map<String, Any?>>>("geofences")
                        ?: emptyList()
                    // Intent extra 로 넘기려면 Serializable 이어야 한다
                    val payload = ArrayList(fences.map { HashMap(it) })
                    val intent = Intent(this, AlertWatchService::class.java)
                        .setAction(AlertWatchService.ACTION_SYNC_GEOFENCES)
                        .putExtra(AlertWatchService.EXTRA_GEOFENCES, payload)
                    try {
                        startForegroundService(intent)
                    } catch (error: Exception) {
                        // 서비스를 못 띄우면 등록도 못 한다 — 다음 목록 변경에서 재시도된다
                    }
                    result.success(null)
                }
                "registeredPlaceIds" -> result.success(
                    AlertWatchService.registeredPlaceIds(),
                )
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

    /**
     * raiseSystemVolume 이 올리기 전의 볼륨. 원복에 쓴다 (이슈 #86).
     *
     * 올리지 않았으면 null 이고 restore 는 아무것도 하지 않는다 —
     * 사용자가 직접 만진 볼륨을 앱이 멋대로 되돌리면 안 된다.
     */
    private var volumeBeforeRaise: Int? = null

    /**
     * 미디어 볼륨을 fraction(0.0~1.0) 수준까지 **올린다**. 이미 그보다
     * 크면 건드리지 않는다 — 크게 듣고 있는 사용자를 낮추면 안 된다.
     */
    private fun raiseSystemVolume(fraction: Double) {
        val audio = getSystemService(AudioManager::class.java) ?: return
        try {
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val target = (max * fraction).toInt().coerceIn(0, max)
            val current = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (current >= target) return
            volumeBeforeRaise = current
            // FLAG 없음 — 볼륨 UI 를 띄우지 않는다. 알림 화면이 뜨는 중에
            // 시스템 볼륨 팝업까지 겹치면 소음이다.
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
        } catch (error: Exception) {
            // 방해금지 등에서 SecurityException 이 올 수 있다 —
            // 볼륨을 못 올려도 재생과 진동은 계속된다
            volumeBeforeRaise = null
        }
    }

    private fun restoreSystemVolume() {
        val saved = volumeBeforeRaise ?: return
        volumeBeforeRaise = null
        val audio = getSystemService(AudioManager::class.java) ?: return
        try {
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, saved, 0)
        } catch (error: Exception) {
            // 원복 실패는 볼륨이 크게 남는 불편이지 고장이 아니다
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
