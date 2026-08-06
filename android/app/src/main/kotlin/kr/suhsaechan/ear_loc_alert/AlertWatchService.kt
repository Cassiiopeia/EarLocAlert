package kr.suhsaechan.ear_loc_alert

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings

/**
 * 감시 상시 유지 + 백그라운드 알림 발화 서비스 (이슈 #74)
 *
 * **왜 필요한가** — 지오펜스 콜백은 전용 isolate 에서 실행된 뒤 즉시 죽는다.
 * 알림을 한 번 띄우고 끝나므로 "해제할 때까지 계속 울린다" 를 만들 수 없고,
 * 절전(Doze)에 들어가면 콜백 자체가 묶여서 늦게 온다. 이 서비스가 프로세스를
 * 살려두고, 알림이 발생하면 앱을 전면으로 띄워 Dart 알림 세션으로 넘긴다.
 *
 * **소리는 절대 내지 않는다.** 이어폰 연결 판정(허용 목록)은 Dart 에 있고
 * 테스트로 지켜지고 있다. 여기서 소리를 내면 그 판정을 우회해 스피커로 샐 수
 * 있다 (docs/03-DOMAIN.md 규칙 5). 이 서비스가 하는 것은 **진동과 화면 띄우기**
 * 뿐이다.
 */
class AlertWatchService : Service() {

    companion object {
        const val ACTION_START_WATCH = "kr.suhsaechan.ear_loc_alert.START_WATCH"
        const val ACTION_STOP_WATCH = "kr.suhsaechan.ear_loc_alert.STOP_WATCH"

        /** Dart 가 알림 세션을 넘겨받았다 — 네이티브 진동을 멈춘다 */
        const val ACTION_STOP_ALERT = "kr.suhsaechan.ear_loc_alert.STOP_ALERT"

        private const val WATCH_CHANNEL_ID = "ear_loc_alert_watch"
        private const val WATCH_NOTIFICATION_ID = 3001

        /**
         * shared_preferences 플러그인은 모든 키에 `flutter.` 를 붙여
         * `FlutterSharedPreferences` XML 에 쓴다. 백그라운드 isolate 가 저장한
         * PendingAlert 를 같은 프로세스에서 감지하는 것이 발화 신호다.
         */
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PENDING_PLACE_ID = "flutter.pending_alert.place_id"

        /**
         * 진동을 무한정 돌리지 않는 안전판.
         *
         * 앱이 끝내 열리지 않는 경우(오버레이 권한 없음·사용자 부재)에도
         * 서랍 속 휴대폰이 배터리를 다 쓰며 떨고 있으면 안 된다. 앱이 열려
         * 세션을 넘겨받으면 Dart 가 해제까지 무제한으로 이어받으므로,
         * 이 상한은 **넘겨받지 못한 경우에만** 걸린다.
         * PendingAlertLauncher 의 유효시간(10분)과 같은 값이다 — 그 시각이
         * 지나면 앱을 열어도 이 알림은 버려진다.
         */
        private const val ALERT_TIMEOUT_MS = 10 * 60 * 1000L

        /** 대기 0.4초 · 진동 0.8초 반복 — 주머니 속에서도 놓치기 어렵게 */
        private val VIBRATION_PATTERN = longArrayOf(400, 800)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var alerting = false

    /**
     * 약한 참조로 보관되므로 필드로 들고 있어야 한다 —
     * 지역 변수로 등록하면 GC 후 조용히 콜백이 끊긴다.
     */
    private val prefsListener =
        SharedPreferences.OnSharedPreferenceChangeListener { changed, key ->
            if (key != KEY_PENDING_PLACE_ID) return@OnSharedPreferenceChangeListener
            // 값이 지워진 것은 앱이 알림을 넘겨받았다는 뜻이다 — 발화 신호가 아니다
            if (changed?.getString(KEY_PENDING_PLACE_ID, null) != null) {
                beginAlert()
            }
        }

    private val prefs: SharedPreferences by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    private val timeoutTask = Runnable { endAlert() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_WATCH -> {
                endAlert()
                stopSelf()
                return START_NOT_STICKY
            }
            // Dart 알림 세션이 이어받는다.
            //
            // 여기서 바로 취소해도 Dart 진동을 죽이지 않는다 — Dart 쪽은
            // 이 채널 호출을 **await 한 뒤에** 자기 진동을 시작한다
            // (app.dart `_resumePendingAlert`). 순서가 보장되므로 겹치지도,
            // 끊기지도 않는다.
            ACTION_STOP_ALERT -> endAlert()
        }

        // 감시 알림은 어떤 경로로 들어와도 유지한다
        if (!startWatchForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }

        // 서비스가 재생성됐는데 이미 대기 중인 알림이 있으면 이어서 울린다
        if (intent?.action == ACTION_START_WATCH && hasPendingAlert()) {
            beginAlert()
        }

        // 프로세스가 죽어도 OS 가 되살린다 — 감시가 조용히 사라지면 안 된다
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeoutTask)
        prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
        if (alerting) stopVibration()
        alerting = false
        super.onDestroy()
    }

    // ---------------------------------------------------------------- 감시 알림

    /** 상시 알림을 띄우고 포그라운드로 승격한다. 실패하면 false. */
    private fun startWatchForeground(): Boolean {
        return try {
            createWatchChannel()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    WATCH_NOTIFICATION_ID,
                    buildWatchNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(WATCH_NOTIFICATION_ID, buildWatchNotification())
            }
            true
        } catch (error: Exception) {
            // API 34+ 는 위치 권한이 없으면 location 타입 승격이 SecurityException 이다.
            // 권한을 받기 전에 호출된 경우가 여기다 — 조용히 물러난다.
            false
        }
    }

    private fun createWatchChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(WATCH_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            WATCH_CHANNEL_ID,
            "위치 감시",
            // 상시 표시되는 알림이다 — 소리도 헤드업도 없어야 한다
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "등록한 장소를 백그라운드에서 지켜보는 중임을 알립니다"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildWatchNotification(): Notification {
        return Notification.Builder(this, WATCH_CHANNEL_ID)
            .setContentTitle("위치를 지켜보고 있습니다")
            .setContentText("도착하거나 떠날 때 알려드립니다")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(launchPendingIntent())
            .build()
    }

    private fun launchPendingIntent(): PendingIntent? {
        val intent = launchIntent() ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ---------------------------------------------------------------- 알림 발화

    private fun hasPendingAlert(): Boolean {
        // 백그라운드 isolate 가 방금 쓴 값을 보려면 캐시가 아니라 파일을 봐야 한다.
        // 같은 프로세스라 getSharedPreferences 가 준 인스턴스는 최신이다.
        return prefs.getString(KEY_PENDING_PLACE_ID, null) != null
    }

    /**
     * 알림을 시작한다 — 반복 진동 + 앱 전면 승격.
     *
     * 이미 울리고 있으면 아무것도 하지 않는다. 여러 지오펜스가 한 이벤트로
     * 묶여 오면 콜백이 연달아 저장하는데, 그때마다 진동을 다시 걸면 패턴이
     * 처음으로 되돌아가 끊긴 것처럼 느껴진다.
     */
    private fun beginAlert() {
        if (alerting) return
        alerting = true

        startVibration()
        launchAlertScreen()

        handler.removeCallbacks(timeoutTask)
        handler.postDelayed(timeoutTask, ALERT_TIMEOUT_MS)
    }

    private fun endAlert() {
        if (!alerting) return
        alerting = false
        handler.removeCallbacks(timeoutTask)
        stopVibration()
    }

    private fun startVibration() {
        try {
            // repeat = 0 — 취소할 때까지 패턴을 처음부터 반복한다.
            // 한 번만 울리고 마는 것이 이 이슈의 증상이었다.
            val effect = VibrationEffect.createWaveform(VIBRATION_PATTERN, 0)
            vibrator.vibrate(effect)
        } catch (error: Exception) {
            // 진동을 못 걸어도 알림과 화면 승격은 계속된다
        }
    }

    private fun stopVibration() {
        try {
            vibrator.cancel()
        } catch (error: Exception) {
            // 중단 실패를 삼킨다 — 해제는 언제나 완료되어야 한다
        }
    }

    /**
     * 알림 화면을 띄운다.
     *
     * "다른 앱 위에 표시" 권한이 있어야 백그라운드에서 액티비티를 시작할 수
     * 있다 — 이것이 영상 시청 중에도 화면을 덮을 수 있는 유일한 경로다.
     * 권한이 없으면 조용히 물러난다: 알림과 진동은 이미 돌고 있고,
     * 잠금화면은 전체화면 알림(FSI)이 담당한다.
     */
    private fun launchAlertScreen() {
        if (!Settings.canDrawOverlays(this)) return
        val intent = launchIntent() ?: return
        try {
            startActivity(intent)
        } catch (error: Exception) {
            // 백그라운드 액티비티 시작이 막혔다 — 알림은 그대로 남는다
        }
    }

    private fun launchIntent(): Intent? {
        return packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
    }
}
