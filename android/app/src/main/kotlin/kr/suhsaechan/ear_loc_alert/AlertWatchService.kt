package kr.suhsaechan.ear_loc_alert

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.graphics.drawable.Icon
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings

/**
 * 감시 상시 유지 + 백그라운드 알림 발화 서비스 (이슈 #74, #93)
 *
 * **왜 필요한가** — 이 서비스가 프로세스를 살려두고, 지오펜스 이벤트가
 * 오면 판정해 반복 진동을 걸고 앱을 전면으로 띄운다.
 *
 * **#93 에서 바뀐 것** — 예전에는 백그라운드 isolate 가 SharedPreferences 에
 * 쓴 값을 리스너로 감지해 발화했다. 그 구조는 이벤트마다 Flutter 엔진을
 * 새로 띄우는 native_geofence 경로에 의존했고, 그 경로가 WorkManager 에
 * 갇혀 이벤트가 통째로 유실됐다. 이제는 이 서비스가 **엔진을 상시 보유**
 * 하고 지오펜스 이벤트를 직접 받아 판정한다. XML 키 감시 의존도 함께
 * 사라졌다 (결정 019 의 "깨지기 쉬운 지점" 해소).
 *
 * **소리는 절대 내지 않는다.** 이어폰 연결 판정(허용 목록)은 Dart 에 있고
 * 테스트로 지켜지고 있다. 여기서 소리를 내면 그 판정을 우회해 스피커로 샐
 * 수 있다 (docs/03-DOMAIN.md 규칙 5). 이 서비스가 하는 것은 **진동과 화면
 * 띄우기** 뿐이다.
 */
class AlertWatchService : Service() {

    companion object {
        const val ACTION_START_WATCH = "kr.suhsaechan.ear_loc_alert.START_WATCH"
        const val ACTION_STOP_WATCH = "kr.suhsaechan.ear_loc_alert.STOP_WATCH"

        /** Dart 가 알림 세션을 넘겨받았다 — 네이티브 진동을 멈춘다 */
        const val ACTION_STOP_ALERT = "kr.suhsaechan.ear_loc_alert.STOP_ALERT"

        /**
         * 사용자가 알림의 "끄기" 버튼을 눌렀다 (이슈 #130).
         *
         * [ACTION_STOP_ALERT] 와 의미가 다르다. 그쪽은 **Dart 세션이
         * 이어받는다**는 뜻이라 알림을 남겨두지만, 이쪽은 사용자가 끝냈다는
         * 뜻이라 알림도 함께 지워야 한다 — 진동만 멈추고 알림이 남으면
         * 사용자는 여전히 "이걸 어떻게 없애지"에 머문다.
         */
        const val ACTION_DISMISS_ALERT = "kr.suhsaechan.ear_loc_alert.DISMISS_ALERT"

        /**
         * 알림의 "끄기" 버튼용 요청 코드 (이슈 #130).
         *
         * 앱 실행용(0)과 달라야 한다 — 같으면 PendingIntent 가 서로 덮어써
         * 버튼을 눌러도 앱만 열린다.
         */
        private const val REQ_STOP_ALERT = 1

        /**
         * 지금 알림이 울리고 있는가 (이슈 #130).
         *
         * **앱 프로세스가 죽었다 살아나도 이 서비스는 살아 있다.** 그때
         * Dart 세션은 사라졌는데 진동은 계속되므로, 앱이 뜰 때 이 값을 보고
         * 정리해야 한다. 그러지 않으면 사용자에게 강제 중지 말고는 방법이
         * 없어진다 — 실제로 그런 일이 있었다.
         */
        @Volatile
        var alertingNow: Boolean = false
            private set

        /** 지오펜스 이벤트 전달 (이슈 #93) */
        const val ACTION_GEOFENCE_EVENT = "kr.suhsaechan.ear_loc_alert.GEOFENCE_EVENT"

        /** 지오펜스 등록 동기화 (이슈 #93) */
        const val ACTION_SYNC_GEOFENCES = "kr.suhsaechan.ear_loc_alert.SYNC_GEOFENCES"

        const val EXTRA_ENTERED = "entered"
        const val EXTRA_PROXIMITY_IDS = "proximity_ids"

        /** 바깥 원(중간 단계 감시 트리거)에 닿은 장소 id (이슈 #260) */
        const val EXTRA_OUTER_IDS = "outer_ids"
        const val EXTRA_PLACE_IDS = "place_ids"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        const val EXTRA_GEOFENCES = "geofences"

        /**
         * 서비스를 띄운 이유 (이슈 #159).
         *
         * 감시가 끊긴 뒤 "누가 언제 되살렸는가"를 알아야 원인을 가릴 수 있다.
         * 없으면 액션으로 추정하고, 인텐트 자체가 없으면 OS 재시작이다.
         */
        const val EXTRA_START_REASON = "start_reason"

        /**
         * 이 프로세스에서 서비스가 살아 있는가 (이슈 #159).
         *
         * 프로세스가 새로 떴다면 항상 false 로 시작하므로, 주기 점검이
         * "서비스가 없다"를 보면 프로세스째 죽었다 살아난 것이다.
         */
        @Volatile
        var isRunning: Boolean = false
            private set

        private const val WATCH_CHANNEL_ID = "ear_loc_alert_watch"
        private const val WATCH_NOTIFICATION_ID = 3001

        /**
         * 도착·출발 알림 채널 (이슈 #102)
         *
         * **왜 새 채널인가** — Dart `BackgroundAlertNotifier` 의
         * `ear_loc_alert_geofence` 는 채널 진동이 켜져 있다. 앱 프로세스가
         * 없는 iOS·구 경로에서는 그것 말고 진동 수단이 없기 때문이다.
         * 여기서는 서비스가 직접 반복 진동을 걸므로 채널 진동이 겹치면
         * 패턴이 어긋난다. 채널 설정은 최초 생성 시 고정되어 나중에 못
         * 바꾸므로, 공유하지 않고 나눈다.
         */
        private const val ARRIVAL_CHANNEL_ID = "ear_loc_alert_arrival"

        /**
         * **Dart `BackgroundAlertNotifier.notificationId` 와 같은 값이다.**
         *
         * 앱이 승격하거나 정리할 때 이 id 로 취소한다 (`app.dart`
         * `_cancelBackgroundNotification`). 한쪽만 바꾸면 지워지지 않는
         * 알림이 남는다.
         */
        private const val ARRIVAL_NOTIFICATION_ID = 2001

        /**
         * 진동을 무한정 돌리지 않는 안전판.
         *
         * 앱이 끝내 열리지 않는 경우(오버레이 권한 없음·사용자 부재)에도
         * 서랍 속 휴대폰이 배터리를 다 쓰며 떨고 있으면 안 된다. 앱이 열려
         * 세션을 넘겨받으면 Dart 가 해제까지 무제한으로 이어받으므로,
         * 이 상한은 **넘겨받지 못한 경우에만** 걸린다.
         * PendingAlertLauncher 의 유효시간(10분)과 같은 값이다.
         */
        private const val ALERT_TIMEOUT_MS = 10 * 60 * 1000L

        /**
         * 근접 반경 안에 오래 머물 때의 배터리 보호 상한 (이슈 #93).
         *
         * 집이 근접 반경 안에 있는 경우처럼 몇 시간씩 머물 수 있다.
         * 그동안 위치 스트림을 돌리면 배터리를 크게 먹는다. 상한에 닿으면
         * 정밀 감시를 끄고 실제 반경 지오펜스 폴백에 맡긴다.
         */
        private const val PRECISE_TIMEOUT_MS = 30 * 60 * 1000L

        /**
         * 알림 시간대가 열리기 이만큼 전부터 중간 단계 감시를 켠다 (이슈 #260).
         * 시간대 밖에서는 켜지 않는 것이 배터리 보호의 핵심이다.
         */
        private const val MID_SCHEDULE_MARGIN_MIN = 30

        /** 시간대·바깥 원 조건을 다시 확인하는 주기. 위치를 받지 않는 메모리 판단이다 */
        private const val MID_GUARD_INTERVAL_MS = 5 * 60 * 1000L

        /** 화면 켜짐마다 위치를 조회하지 않게 막는 최소 간격 */
        private const val SCREEN_CHECK_THROTTLE_MS = 30_000L

        /**
         * 중간 단계 측정이 근접 원 이 거리(m) 안쪽까지 오면 정밀 감시로 올린다.
         * 측정 간격(약 60초, 시속 60km 에서 1km)과 정확도 오차를 흡수하는 여유다.
         */
        private const val PRECISE_START_MARGIN_M = 1_000f

        /** 대기 0.4초 · 진동 0.8초 반복 — 주머니 속에서도 놓치기 어렵게 */
        private val VIBRATION_PATTERN = longArrayOf(400, 800)

        /**
         * 마지막으로 등록한 place id.
         *
         * `MainActivity` 의 채널이 앱 쪽에서 조회할 수 있게 정적으로 둔다 —
         * 서비스 인스턴스에 바인딩하지 않고 값만 읽는 용도다.
         */
        @Volatile
        private var lastRegisteredIds: List<String> = emptyList()

        fun registeredPlaceIds(): List<String> = lastRegisteredIds
    }

    private val handler = Handler(Looper.getMainLooper())
    private var alerting = false

    /**
     * 지금 울리고 있는 알림의 내용 (이슈 #102).
     *
     * 시간 초과로 알림을 다시 달 때 장소 이름을 그대로 유지하기 위해
     * 들고 있는다. 없으면 "위치 알림"으로 떨어진다.
     */
    private var lastDecision: AlertDecision? = null

    /** 판정을 수행하는 Dart 엔진 (이슈 #93) */
    private val engine by lazy { WatchEngine(this) }

    private val registrar by lazy { GeofenceRegistrar(this) }
    private val tracker by lazy { PreciseLocationTracker(this) }

    /** 정밀 감시를 요구하는 장소들. 비면 스트림을 끈다 */
    private val proximityPlaces = mutableSetOf<String>()

    // ---- 중간 단계 감시 (이슈 #260)

    /** 네이티브가 아는 장소 목록. 등록 맵과 같은 시점에 갱신된다 */
    private var places: List<WatchPlace> = emptyList()

    /** 바깥 원 안에 있다고 알고 있는 장소들. 비면 중간 단계를 끈다 */
    private val outerPlaces = mutableSetOf<String>()

    private val midTracker by lazy { CoarseLocationTracker(this) }
    private val locationProvider by lazy { CurrentLocationProvider(this) }
    private var midStartedElapsedMs = 0L
    private var midFixCount = 0
    private var lastScreenCheckElapsedMs = 0L
    private var screenReceiverRegistered = false

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

    private val timeoutTask = Runnable { endAlert(timedOut = true) }
    private val preciseTimeoutTask = Runnable { stopPreciseTracking() }
    private val midGuardTask = Runnable { reconcileMid("guard_tick") }

    /**
     * 화면 켜짐 수신 (이슈 #260).
     *
     * OS 가 지오펜스 평가를 미루다가 사용자가 화면을 켜는 순간에야 이벤트를
     * 내보내는 경우가 있다. 그 전에 앱이 먼저 현재 위치를 확인한다.
     */
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_ON) onScreenOn()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        val startedAt = SystemClock.elapsedRealtime()
        super.onCreate()

        // **엔진보다 먼저 포그라운드로 올린다** (이슈 #161).
        //
        // `startForegroundService()` 로 시작하면 OS 는 약 10초 안에 승격하기를
        // 요구하고, 넘기면 프로세스째 죽인다
        // (`ForegroundServiceDidNotStartInTimeException`). 예전에는 승격이
        // `onStartCommand` 에 있어서 그 앞의 엔진 부팅이 끝나야 도달했다.
        // 엔진 부팅은 프로세스가 콜드일 때(부팅·앱 교체·킬 뒤) 부하가 크면
        // 수 초에서 수십 초까지 늘어난다 — 에뮬레이터에서 34초로 크래시를 재현했다.
        // 크래시는 프로세스째 일어나 진단 기록에 흔적이 남지 않는다.
        if (!startWatchForeground()) {
            // API 34+ 는 위치 권한이 없으면 승격이 거부된다. 권한 온보딩 전에
            // 불린 경우이며, 엔진을 띄울 이유가 없다
            DiagnosticLog.write(this, "watch", "watch service promotion failed, stopping")
            stopSelf()
            return
        }
        val promotedMs = SystemClock.elapsedRealtime() - startedAt

        // 서비스가 살아있는지가 알림 발화의 전제다 — 죽은 구간을
        // 시간순으로 확인할 수 있어야 한다 (이슈 #95).
        // 승격까지 걸린 시간을 함께 남긴다 — OS 한도(약 10초)에 얼마나
        // 가까웠는지 실기기에서 보려는 것이다 (이슈 #161)
        DiagnosticLog.write(this, "watch", "watch service created (promoted in ${promotedMs}ms)")
        isRunning = true

        // 직전 프로세스가 왜 죽었는지 남긴다 — 감시가 끊긴 원인의 유일한 단서다 (이슈 #159)
        ExitReasonLogger.logNew(this)
        // 주기 점검 알람은 재부팅·앱 교체·강제 종료로 사라진다. 서비스가 뜰 때마다 다시 건다
        WatchdogReceiver.schedule(this)

        // 엔진이 저장된 장소로 등록을 복원하면 그대로 OS 에 밀어넣는다 (이슈 #93).
        // **재부팅 후 앱을 켜지 않아도 감시가 되살아나는 지점이다** — OS 는
        // 재부팅 시 지오펜스를 잃고, 예전에는 앱이 켜져야만 다시 등록됐다.
        engine.onSyncRequested = { fences -> applyGeofences(fences) }

        // 엔진을 먼저 띄운다 — 이벤트가 오기 전에 준비되어야 한다.
        // 부팅 중 도착한 요청은 WatchEngine 이 큐에 담았다가 흘려보낸다.
        // **이 호출은 생성 단계에서 동기로 유지한다** — 비동기로 미루면 그 사이 온
        // 지오펜스 이벤트가 채널 없이 판정 없음으로 떨어져 도착이 유실된다.
        // 승격은 이미 끝났으므로 여기가 느려도 OS 한도에 걸리지 않는다 (이슈 #161).
        engine.start()
        DiagnosticLog.write(
            this,
            "watch",
            "watch engine started in ${SystemClock.elapsedRealtime() - startedAt}ms",
        )

        // 저장된 사본으로 장소를 복원한다 — 서비스가 다시 떴을 때도 중간 단계
        // 판단이 가능해야 한다 (등록 맵이 다시 오지 않을 수 있다)
        // 기기·앱 정보 — 이 기록만 보고도 "어떤 기기·어떤 상태에서" 났는지 알 수 있게 한다
        DiagnosticLog.write(this, "device", DeviceInfo.summary(this))
        places = WatchState.loadFences(this).mapNotNull(WatchPlace::fromMap)
        registerScreenReceiver()
        DiagnosticLog.write(
            this,
            "tier",
            "tier state restored places=${places.size} " +
                "outer_enabled=${places.count { it.outerRadiusMeters > 0f }} ${DeviceState.snapshot(this)}",
        )
        // 서비스가 막 떴다 = 그동안 놓친 이벤트가 있을 수 있다. 현재 위치로 한 번 맞춘다
        handler.post { checkNow("service_created") }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 시작 사유 (이슈 #159) — 이벤트 전달은 지오펜스 로그가 따로 있어 제외한다
        if (intent?.action != ACTION_GEOFENCE_EVENT) {
            val reason = intent?.getStringExtra(EXTRA_START_REASON)
                ?: if (intent == null) "system_restart" else "action=${intent.action}"
            DiagnosticLog.write(this, "watch", "service start requested reason=$reason")
        }

        when (intent?.action) {
            ACTION_STOP_WATCH -> {
                endAlert()
                stopPreciseTracking()
                outerPlaces.clear()
                reconcileMid("watch_stopped")
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
            // 사용자가 알림에서 직접 껐다 (이슈 #130) — Dart 를 거치지
            // 않으므로 앱이 죽어 있어도 여기서 끝난다
            ACTION_DISMISS_ALERT -> {
                DiagnosticLog.write(this, "alert", "alert dismissed by the user from the notification")
                endAlert()
                cancelArrivalNotification()
            }
        }

        // 감시 알림은 어떤 경로로 들어와도 유지한다
        if (!startWatchForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent?.action) {
            ACTION_GEOFENCE_EVENT -> handleGeofenceEvent(intent)
            ACTION_SYNC_GEOFENCES -> handleSyncGeofences(intent)
        }

        // 프로세스가 죽어도 OS 가 되살린다 — 감시가 조용히 사라지면 안 된다
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        DiagnosticLog.write(this, "watch", "watch service destroyed")
        handler.removeCallbacks(timeoutTask)
        handler.removeCallbacks(preciseTimeoutTask)
        handler.removeCallbacks(midGuardTask)
        stopPreciseTracking()
        if (midTracker.isRunning) {
            midTracker.stop()
            DiagnosticLog.write(this, "mid", "mid tracking stopped reason=service_destroyed fixes=$midFixCount")
        }
        if (screenReceiverRegistered) {
            try {
                unregisterReceiver(screenReceiver)
            } catch (error: Exception) {
                DiagnosticLog.write(this, "screen", "screen receiver unregister failed $error")
            }
            screenReceiverRegistered = false
        }
        engine.stop()
        if (alerting) stopVibration()
        alerting = false
        alertingNow = false
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
            // 권한을 받기 전에 호출된 경우가 여기다 — 기록만 남기고 물러난다
            DiagnosticLog.write(this, "watch", "foreground promotion failed $error")
            false
        }
    }

    private fun createWatchChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val text = AppLocale.localized(this)
        // **이미 있어도 다시 만든다.** OS 는 채널 이름과 설명을 만든 시점의 언어로
        // 굳히지만, 같은 아이디로 다시 만들면 이름과 설명만 갱신되고 진동과 소리
        // 같은 사용자 설정은 그대로 남는다. 언어를 바꾼 뒤에도 설정 화면의 채널
        // 이름이 바뀐 언어로 보이게 하려는 것이다 (이슈 #164)
        val channel = NotificationChannel(
            WATCH_CHANNEL_ID,
            text.getString(R.string.watch_channel_name),
            // 상시 표시되는 알림이다 — 소리도 헤드업도 없어야 한다
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = text.getString(R.string.watch_channel_description)
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildWatchNotification(): Notification {
        val text = AppLocale.localized(this)
        return Notification.Builder(this, WATCH_CHANNEL_ID)
            .setContentTitle(text.getString(R.string.watch_notification_title))
            .setContentText(text.getString(R.string.watch_notification_text))
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(launchPendingIntent())
            .build()
    }

    /**
     * 알림의 "끄기" 버튼이 보낼 신호 (이슈 #130).
     *
     * `getService` 라 **앱 프로세스와 무관하게** 이 서비스가 직접 받는다.
     * 진동을 멈추고 알림까지 지운다.
     */
    private fun stopAlertPendingIntent(): PendingIntent {
        val intent = Intent(this, AlertWatchService::class.java)
            .setAction(ACTION_DISMISS_ALERT)
        return PendingIntent.getService(
            this,
            REQ_STOP_ALERT,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
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

    // ------------------------------------------------------------ 지오펜스 처리

    /** 앱이 보낸 등록 목록을 OS 에 반영한다 (이슈 #93) */
    private fun handleSyncGeofences(intent: Intent) {
        @Suppress("UNCHECKED_CAST", "DEPRECATION")
        val fences = intent.getSerializableExtra(EXTRA_GEOFENCES)
            as? ArrayList<HashMap<String, Any?>>
        if (fences == null) {
            DiagnosticLog.write(this, "sync", "geofence sync skipped reason=invalid_extra")
            return
        }
        applyGeofences(fences)
    }

    /**
     * 등록 목록을 OS 에 반영한다.
     *
     * 두 경로가 공유한다 — 앱이 보낸 것(`ACTION_SYNC_GEOFENCES`)과 엔진이
     * 재부팅 후 스스로 복원한 것(`WatchEngine.onSyncRequested`).
     */
    private fun applyGeofences(fences: List<Map<String, Any?>>) {
        registrar.sync(fences)
        lastRegisteredIds = registrar.registeredIds()

        // 서비스가 없어도 복구할 수 있게 네이티브 사본을 남긴다 (이슈 #159)
        WatchState.saveFences(this, fences)
        WatchState.markRegistered(this)

        // 중간 단계 판단용 장소 목록도 같은 시점에 맞춘다 (이슈 #260)
        places = fences.mapNotNull(WatchPlace::fromMap)
        val knownIds = places.map { it.id }.toSet()
        outerPlaces.retainAll(knownIds)
        DiagnosticLog.write(
            this,
            "tier",
            "tier places synced places=${places.size} " +
                places.joinToString(" ") {
                    "${it.shortId}(r=${it.radiusMeters.toInt()} prox=${it.proximityRadiusMeters.toInt()} " +
                        "outer=${it.outerRadiusMeters.toInt()} windows=${it.windows.size})"
                },
        )
        reconcileMid("sync")

        // 등록 개수가 0 이면 어떤 도착도 감지되지 않는다 (이슈 #95)
        DiagnosticLog.write(
            this,
            "watch",
            "native geofences registered=${lastRegisteredIds.size} requested=${fences.size}",
        )

        // 등록 대상이 사라지면 정밀 감시도 의미가 없다
        if (fences.isEmpty()) stopPreciseTracking()
    }

    /**
     * 지오펜스 이벤트를 처리한다 (이슈 #93).
     *
     * **근접 반경**은 정밀 감시를 켜고 끈다 — 그 자체로는 알림이 아니다.
     * **실제 반경**은 판정 대상이다. 정밀 감시가 죽어 있어도(권한 취소·
     * 스트림 오류) 이 경로로 알림이 나간다.
     *
     * 두 경로가 같은 상태 저장소(Drift)를 보므로 어느 쪽이 먼저 도착하든
     * 두 번째는 전이가 없어 조용히 넘어간다 — 중복 발화가 구조적으로 막힌다.
     */
    private fun handleGeofenceEvent(intent: Intent) {
        val entered = intent.getBooleanExtra(EXTRA_ENTERED, false)
        val proximityIds = intent.getStringArrayListExtra(EXTRA_PROXIMITY_IDS).orEmpty()
        val placeIds = intent.getStringArrayListExtra(EXTRA_PLACE_IDS).orEmpty()
        val outerIds = intent.getStringArrayListExtra(EXTRA_OUTER_IDS).orEmpty()
        val latitude =
            if (intent.hasExtra(EXTRA_LATITUDE)) intent.getDoubleExtra(EXTRA_LATITUDE, 0.0)
            else null
        val longitude =
            if (intent.hasExtra(EXTRA_LONGITUDE)) intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0)
            else null

        // 바깥 원은 중간 단계 위치 감시를 켜고 끈다 (이슈 #260)
        if (outerIds.isNotEmpty()) {
            if (entered) outerPlaces += outerIds else outerPlaces -= outerIds.toSet()
            DiagnosticLog.write(
                this,
                "tier",
                "outer ring ${if (entered) "ENTER" else "EXIT"} " +
                    "places=${outerIds.joinToString(",") { it.take(8) }} " +
                    "outer_inside=${outerPlaces.size} ${DeviceState.snapshot(this)}",
            )
            reconcileMid(if (entered) "outer_enter" else "outer_exit")
        }

        if (proximityIds.isNotEmpty()) {
            DiagnosticLog.write(
                this,
                "tier",
                "proximity ring ${if (entered) "ENTER" else "EXIT"} " +
                    "places=${proximityIds.joinToString(",") { it.take(8) }} " +
                    "mid_running=${midTracker.isRunning} precise_running=${tracker.isRunning}",
            )
            if (entered) startPreciseTracking(proximityIds)
            else stopPreciseTrackingIfIdle(proximityIds)
        }

        for (placeId in placeIds) {
            engine.evaluateOsTransition(placeId, entered, latitude, longitude) { decision ->
                if (decision.shouldAlert) beginAlert(decision)
            }
        }
    }

    // ------------------------------------------------------ 중간 단계 감시 (#260)

    /**
     * 중간 단계 위치 감시를 켜고 끌지 정한다.
     *
     * **켜는 조건** — 바깥 원 안에 있고, 그 장소의 알림 시간대가 열려 있거나
     * [MID_SCHEDULE_MARGIN_MIN] 분 안에 열린다. 둘 중 하나라도 어긋나면 끈다.
     *
     * 이벤트가 올 때마다, 장소 목록이 바뀔 때마다, 그리고 주기적으로 부른다.
     * 주기 호출은 "아직 안 열렸던 시간대가 열렸는가"를 잡는다 — 바깥 원
     * 이벤트는 시간대와 무관하게 한 번만 오기 때문이다.
     */
    private fun reconcileMid(reason: String) {
        handler.removeCallbacks(midGuardTask)

        val nowMs = System.currentTimeMillis()
        val inside = places.filter { it.id in outerPlaces }
        val eligible = inside.filter { it.isScheduleActive(nowMs, MID_SCHEDULE_MARGIN_MIN) }

        if (eligible.isNotEmpty()) {
            if (!midTracker.isRunning) {
                val started = midTracker.start { location -> handleFix(location, "mid") }
                if (started) {
                    midStartedElapsedMs = SystemClock.elapsedRealtime()
                    midFixCount = 0
                    DiagnosticLog.write(
                        this,
                        "mid",
                        "mid tracking started reason=$reason " +
                            "targets=${eligible.joinToString(",") { it.shortId }} " +
                            "outer_inside=${inside.size} ${DeviceState.snapshot(this)}",
                    )
                } else {
                    DiagnosticLog.write(this, "mid", "mid tracking start failed reason=permission_missing")
                }
            }
        } else {
            if (midTracker.isRunning) {
                midTracker.stop()
                val ranS = (SystemClock.elapsedRealtime() - midStartedElapsedMs) / 1000
                DiagnosticLog.write(
                    this,
                    "mid",
                    "mid tracking stopped reason=${if (inside.isEmpty()) "left_outer_ring" else "outside_schedule"} " +
                        "trigger=$reason fixes=$midFixCount ran_s=$ranS ${DeviceState.snapshot(this)}",
                )
            } else if (inside.isNotEmpty()) {
                // 바깥 원 안인데 시간대가 아니라 안 켜는 경우 — 안 울린 이유를 남긴다
                DiagnosticLog.write(
                    this,
                    "mid",
                    "mid tracking idle reason=outside_schedule trigger=$reason " +
                        "outer_inside=${inside.joinToString(",") { it.shortId }}",
                )
            }
        }

        // 바깥 원 안에 있는 동안은 시간대 변화를 계속 지켜본다
        if (outerPlaces.isNotEmpty()) handler.postDelayed(midGuardTask, MID_GUARD_INTERVAL_MS)
    }

    /**
     * 위치 한 건을 처리한다 — 중간 단계 측정·화면 켜짐·서비스 시작 때 공통이다.
     *
     * 하는 일: ① 바깥 원 소속을 실측으로 바로잡고 ② 근접 원 근처면 정밀
     * 감시로 올리고 ③ 기존 판정기에 넘긴다. **알림 여부는 ③ 이 정한다.**
     */
    private fun handleFix(location: Location, source: String) {
        if (source == "mid") midFixCount++
        val nowMs = System.currentTimeMillis()
        val ageS = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000_000L

        // 장소별 거리 — 안 울린 이유를 사후에 가리려면 거리가 전부 있어야 한다
        val distances = places.associateWith { it.distanceTo(location.latitude, location.longitude) }
        DiagnosticLog.write(
            this,
            "mid",
            "fix source=$source lat=${location.latitude} lng=${location.longitude} " +
                "acc=${location.accuracy.toInt()}m age_s=$ageS provider=${location.provider} " +
                "mid_fixes=$midFixCount " +
                distances.entries.joinToString(" ") { (place, dist) ->
                    "${place.shortId}:dist=${dist.toInt()}m" +
                        "(actual=${place.radiusMeters.toInt()} prox=${place.proximityRadiusMeters.toInt()} " +
                        "outer=${place.outerRadiusMeters.toInt()} " +
                        "schedule=${place.isScheduleActive(nowMs, MID_SCHEDULE_MARGIN_MIN)})"
                },
        )

        // ① 바깥 원 소속을 실측으로 맞춘다 — OS 이벤트가 늦거나 없어도 어긋나지 않게
        var membershipChanged = false
        for ((place, dist) in distances) {
            if (place.outerRadiusMeters <= 0f) continue
            val inside = dist <= place.outerRadiusMeters
            if (inside && outerPlaces.add(place.id)) membershipChanged = true
            if (!inside && outerPlaces.remove(place.id)) membershipChanged = true
        }
        if (membershipChanged) {
            DiagnosticLog.write(
                this,
                "tier",
                "outer membership corrected by fix source=$source outer_inside=${outerPlaces.size}",
            )
        }

        // ② 근접 원 근처(여유 포함)면 정밀 감시로 올린다. 시간대 밖이면 올리지 않는다
        val near = distances.filter { (place, dist) ->
            dist <= place.proximityRadiusMeters + PRECISE_START_MARGIN_M &&
                place.isScheduleActive(nowMs, MID_SCHEDULE_MARGIN_MIN)
        }.keys.map { it.id }
        if (near.isNotEmpty() && !tracker.isRunning) {
            DiagnosticLog.write(
                this,
                "tier",
                "precise start requested by fix source=$source " +
                    "targets=${near.joinToString(",") { it.take(8) }}",
            )
            startPreciseTracking(near)
        }

        // ③ 기존 판정기에 넘긴다 — 중복 발화는 상태 전이가 막는다
        engine.evaluatePosition(
            latitude = location.latitude,
            longitude = location.longitude,
            accuracyMeters = location.accuracy.toDouble(),
            timestampMs = location.time,
        ) { decision ->
            if (decision.shouldAlert) beginAlert(decision)
        }

        reconcileMid("fix_$source")
    }

    /**
     * 현재 위치를 1회 조회해 [handleFix] 로 처리한다.
     *
     * **GPS 를 켜지 않는다.** 균형 전력으로 최근 값(1분 이내)을 우선 쓰고,
     * 없으면 짧게(5초) 기다린다. 화면 켜짐마다 불리므로 가벼워야 한다.
     */
    private fun checkNow(reason: String) {
        val nowMs = System.currentTimeMillis()
        if (places.none { it.isScheduleActive(nowMs, MID_SCHEDULE_MARGIN_MIN) }) {
            DiagnosticLog.write(
                this,
                "mid",
                "one-shot check skipped reason=$reason cause=no_active_schedule places=${places.size}",
            )
            return
        }
        if (alerting) {
            DiagnosticLog.write(this, "mid", "one-shot check skipped reason=$reason cause=alerting")
            return
        }
        locationProvider.fetch(
            priority = com.google.android.gms.location.Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            durationMs = 5_000L,
            maxAgeMs = 60_000L,
        ) { location ->
            if (location == null) {
                DiagnosticLog.write(this, "mid", "one-shot check failed reason=$reason cause=no_location")
            } else {
                handleFix(location, reason)
            }
        }
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) return
        try {
            val filter = IntentFilter(Intent.ACTION_SCREEN_ON)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
            screenReceiverRegistered = true
        } catch (error: Exception) {
            // 등록 실패는 기능이 하나 줄 뿐이다 — 기록만 남기고 감시는 계속한다
            DiagnosticLog.write(this, "screen", "screen receiver register failed $error")
        }
    }

    private fun onScreenOn() {
        val now = SystemClock.elapsedRealtime()
        val sinceLastS =
            if (lastScreenCheckElapsedMs == 0L) "first" else ((now - lastScreenCheckElapsedMs) / 1000).toString()
        if (lastScreenCheckElapsedMs != 0L && now - lastScreenCheckElapsedMs < SCREEN_CHECK_THROTTLE_MS) {
            DiagnosticLog.write(this, "screen", "screen on, check skipped cause=throttled since_last_s=$sinceLastS")
            return
        }
        lastScreenCheckElapsedMs = now
        DiagnosticLog.write(
            this,
            "screen",
            "screen on, checking position since_last_s=$sinceLastS " +
                "mid_running=${midTracker.isRunning} precise_running=${tracker.isRunning} " +
                "alerting=$alerting places=${places.size} ${DeviceState.snapshot(this)}",
        )
        checkNow("screen_on")
    }

    // ------------------------------------------------------------ 정밀 감시

    private fun startPreciseTracking(placeIds: List<String>) {
        proximityPlaces += placeIds
        handler.removeCallbacks(preciseTimeoutTask)
        handler.postDelayed(preciseTimeoutTask, PRECISE_TIMEOUT_MS)
        if (tracker.isRunning) return

        DiagnosticLog.write(this, "precise", "precise tracking started targets=${proximityPlaces.size}")

        tracker.start { location ->
            engine.evaluatePosition(
                latitude = location.latitude,
                longitude = location.longitude,
                accuracyMeters = location.accuracy.toDouble(),
                timestampMs = location.time,
            ) { decision ->
                if (decision.shouldAlert) beginAlert(decision)
            }
        }
    }

    private fun stopPreciseTrackingIfIdle(placeIds: List<String>) {
        proximityPlaces -= placeIds.toSet()
        if (proximityPlaces.isEmpty()) stopPreciseTracking()
    }

    private fun stopPreciseTracking() {
        if (tracker.isRunning) {
            DiagnosticLog.write(this, "precise", "precise tracking stopped")
        }
        handler.removeCallbacks(preciseTimeoutTask)
        proximityPlaces.clear()
        tracker.stop()
    }

    // ---------------------------------------------------------------- 알림 발화

    /**
     * 알림을 시작한다 — **OS 알림 + 반복 진동 + 앱 전면 승격.**
     *
     * 이미 울리고 있으면 아무것도 하지 않는다. 여러 지오펜스가 한 이벤트로
     * 묶여 오면 판정이 연달아 돌아오는데, 그때마다 진동을 다시 걸면 패턴이
     * 처음으로 되돌아가 끊긴 것처럼 느껴진다.
     *
     * **알림이 먼저다** (이슈 #102). 화면 승격은 오버레이 권한과 백그라운드
     * 액티비티 시작 제한에 걸려 실패할 수 있고, 실제로 그랬다 — 그러면
     * 진동만 울리고 화면에는 아무 흔적도 남지 않았다. 알림은 어떤 권한
     * 상태에서도 뜨고, 그것이 해제 화면에 닿는 마지막 길이다.
     */
    private fun beginAlert(decision: AlertDecision) {
        if (alerting) {
            DiagnosticLog.write(this, "alert", "already ringing, duplicate fire ignored")
            return
        }
        alerting = true
        alertingNow = true

        DiagnosticLog.write(
            this,
            "alert",
            "alert started place=${decision.placeName} " +
                "direction=${decision.direction} " +
                "(overlay_permission=${Settings.canDrawOverlays(this)})",
        )

        lastDecision = decision

        // 순서가 의미를 가진다 — 승격이 막혀도 알림과 진동은 남는다
        showArrivalNotification(decision)
        startVibration(decision)
        launchAlertScreen()

        handler.removeCallbacks(timeoutTask)
        handler.postDelayed(timeoutTask, ALERT_TIMEOUT_MS)
    }

    /**
     * 끝나는 경로가 둘이라 [timedOut] 으로 갈린다.
     *
     * **Dart 가 넘겨받은 경우**(`ACTION_STOP_ALERT`)는 앱이 알림을 직접
     * 지운다 — 여기서 손대면 앱의 정리와 겹친다.
     *
     * **시간 초과**는 사용자가 끝내 열지 않은 경우다. 진동은 멎지만 알림은
     * 남겨야 "그때 도착했었다"가 사라지지 않는다. 다만 계속 `ongoing` 이면
     * 스와이프로도 못 지우는 알림이 영영 남으므로 지울 수 있게 바꿔 단다.
     */
    private fun endAlert(timedOut: Boolean = false) {
        if (!alerting) return
        alerting = false
        alertingNow = false
        handler.removeCallbacks(timeoutTask)
        stopVibration()
        if (timedOut) {
            DiagnosticLog.write(this, "alert", "alert timed out, vibration stopped, notification kept")
            releaseArrivalNotification()
        }
    }

    // ------------------------------------------------------- 도착·출발 알림

    /**
     * 도착·출발 알림을 띄운다 (이슈 #102).
     *
     * **소리는 내지 않는다.** 채널을 무음으로 만든다 — 이어폰 연결 판정은
     * Dart 에만 있고, 여기서 소리가 나가면 그 판정을 우회해 스피커로 샌다
     * (docs/03-DOMAIN.md 규칙 5, docs/10-DECISIONS.md 019).
     *
     * 전체화면 인텐트를 건다. 화면이 꺼졌거나 잠겨 있으면 알림 화면이
     * 바로 올라오고, 켜져 있으면 OS 가 헤드업으로 강등한다 — 그 경우는
     * [launchAlertScreen] 이 담당한다. Android 14+ 에서 권한이 없으면
     * 조용히 헤드업으로 떨어질 뿐 알림 자체는 뜬다.
     */
    private fun showArrivalNotification(decision: AlertDecision) {
        try {
            createArrivalChannel()
            val manager = getSystemService(NotificationManager::class.java)
            if (manager == null) {
                DiagnosticLog.write(this, "alert", "notification post skipped reason=no_manager")
                return
            }
            manager.notify(
                ARRIVAL_NOTIFICATION_ID,
                buildArrivalNotification(decision, ongoing = true),
            )
        } catch (error: Exception) {
            // 알림 권한이 없으면 여기서 막힌다 — 진동과 화면 승격은 계속된다.
            // 무엇이 막혔는지는 남긴다. 아무것도 안 뜨는 이유가 이것일 수 있다
            DiagnosticLog.write(this, "alert", "notification post failed $error")
        }
    }

    /** 사용자가 알림의 "끄기"로 끝냄 > 알림 제거 */
    private fun cancelArrivalNotification() {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager == null) {
                DiagnosticLog.write(this, "alert", "notification cancel skipped reason=no_manager")
                return
            }
            manager.cancel(ARRIVAL_NOTIFICATION_ID)
        } catch (error: Exception) {
            DiagnosticLog.write(this, "alert", "notification cancel failed error=$error")
        }
    }

    /** 시간 초과 후 스와이프로 지울 수 있게 다시 단다 */
    private fun releaseArrivalNotification() {
        try {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            manager.notify(
                ARRIVAL_NOTIFICATION_ID,
                buildArrivalNotification(lastDecision, ongoing = false),
            )
        } catch (error: Exception) {
            // 실패하면 지울 수 없는 알림이 남는다 — 앱을 열면 정리된다
            DiagnosticLog.write(this, "alert", "notification release failed $error")
        }
    }

    private fun createArrivalChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val text = AppLocale.localized(this)
        // 이미 있어도 다시 만든다 — 이름과 설명만 갱신된다 (createWatchChannel 참조, 이슈 #164)
        val channel = NotificationChannel(
            ARRIVAL_CHANNEL_ID,
            text.getString(R.string.arrival_channel_name),
            // 헤드업으로 뜨려면 HIGH 이상이어야 한다
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = text.getString(R.string.arrival_channel_description)
            // 진동은 서비스가 직접 건다 — 채널 진동과 겹치면 패턴이 어긋난다
            enableVibration(false)
            // **소리 없음.** 이어폰 판정을 우회할 수 없어야 한다
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildArrivalNotification(
        decision: AlertDecision?,
        ongoing: Boolean,
    ): Notification {
        val text = AppLocale.localized(this)
        val title = decision?.placeName?.takeIf { it.isNotBlank() }
            ?: text.getString(R.string.arrival_default_title)
        val body = text.getString(
            if (decision?.direction == "exit") R.string.arrival_body_exit
            else R.string.arrival_body_enter,
        )
        val pending = launchPendingIntent()

        return Notification.Builder(this, ARRIVAL_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(applicationInfo.icon)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(pending)
            // **스와이프로 지워지지 않는다** (이슈 #84 와 같은 이유).
            // 울리는 중에 알림을 잃으면 끌 방법이 사라진다.
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .apply {
                // 화면이 꺼졌거나 잠겼을 때 알림 화면을 직접 띄운다.
                // 시간 초과 후에는 화면을 깨울 이유가 없다
                if (ongoing && pending != null) setFullScreenIntent(pending, true)

                // **끄기 버튼** (이슈 #130).
                //
                // 앱이 죽으면 Dart 가 해제 신호를 보낼 수 없고, 알림을 탭해
                // 앱을 열어도 세션이 없어 알림 화면이 뜨지 않는다. 그러면
                // 사용자에게 남는 선택지가 강제 중지뿐이다 — 실제로 그런
                // 일이 있었다.
                //
                // 이 버튼은 **서비스로 직접 간다.** Dart 를 거치지 않으므로
                // 앱이 죽어 있어도 멈춘다.
                if (ongoing) {
                    addAction(
                        Notification.Action.Builder(
                            Icon.createWithResource(
                                this@AlertWatchService,
                                android.R.drawable.ic_menu_close_clear_cancel,
                            ),
                            text.getString(R.string.arrival_action_dismiss),
                            stopAlertPendingIntent(),
                        ).build(),
                    )
                }
            }
            .build()
    }

    /**
     * 반복 진동을 시작한다.
     *
     * 세기는 Dart 가 판정 결과에 실어 보낸 값을 쓴다 (이슈 #103).
     * 값이 없거나 기기가 진폭 제어를 지원하지 않으면 **길이만** 반영한다 —
     * 진폭 제어가 없는 기기가 아직 많고, 그런 기기에서 세기 설정이 아무
     * 효과도 없으면 사용자는 설정이 고장 났다고 판단한다.
     */
    private fun startVibration(decision: AlertDecision) {
        try {
            val pulse = decision.vibrationPulseMs.takeIf { it > 0 }?.toLong()
                ?: VIBRATION_PATTERN[1]
            val pattern = longArrayOf(VIBRATION_PATTERN[0], pulse)

            val canControlAmplitude =
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    vibrator.hasAmplitudeControl() &&
                    decision.vibrationAmplitude > 0

            // repeat = 0 — 취소할 때까지 패턴을 처음부터 반복한다.
            // 한 번만 울리고 마는 것이 이슈 #74 의 증상이었다.
            val effect = if (canControlAmplitude) {
                // 대기 구간은 진폭 0 이어야 한다 — 패턴과 길이가 같아야 하고,
                // 첫 칸에 세기를 주면 쉬는 동안에도 떨린다
                val amplitudes = intArrayOf(0, decision.vibrationAmplitude)
                VibrationEffect.createWaveform(pattern, amplitudes, 0)
            } else {
                VibrationEffect.createWaveform(pattern, 0)
            }
            vibrator.vibrate(effect)
        } catch (error: Exception) {
            // 진동을 못 걸어도 알림과 화면 승격은 계속된다
            DiagnosticLog.write(this, "alert", "vibration start failed $error")
        }
    }

    private fun stopVibration() {
        try {
            vibrator.cancel()
        } catch (error: Exception) {
            // 중단 실패를 삼킨다 — 해제는 언제나 완료되어야 한다 (기록만 남김)
            DiagnosticLog.write(this, "alert", "vibration stop failed $error")
        }
    }

    /**
     * 알림 화면을 띄운다.
     *
     * "다른 앱 위에 표시" 권한이 있어야 백그라운드에서 액티비티를 시작할 수
     * 있다 — 이것이 **화면이 켜져 있는 동안** 영상 위로 화면을 덮을 수 있는
     * 유일한 경로다. 화면이 꺼졌거나 잠긴 경우는 전체화면 인텐트가 담당한다.
     *
     * 실패해도 알림과 진동은 이미 돌고 있으므로 조용히 물러난다. 다만
     * **왜 실패했는지는 남긴다** (이슈 #102) — 예전에는 아무것도 남기지
     * 않아 "화면이 왜 안 뜨는가"를 진단 기록으로 추적할 수 없었다.
     */
    private fun launchAlertScreen() {
        if (!Settings.canDrawOverlays(this)) {
            DiagnosticLog.write(
                this,
                "alert",
                "screen promotion skipped, no draw-over-other-apps permission (notification was posted)",
            )
            return
        }
        val intent = launchIntent()
        if (intent == null) {
            DiagnosticLog.write(this, "alert", "screen promotion skipped reason=no_launch_intent")
            return
        }
        try {
            startActivity(intent)
            DiagnosticLog.write(this, "alert", "screen promotion requested")
        } catch (error: Exception) {
            // Android 10+ 는 권한이 있어도 백그라운드 액티비티 시작을 막을 수
            // 있다. 그 경우 전체화면 인텐트와 알림이 남는다
            DiagnosticLog.write(this, "alert", "screen promotion blocked $error")
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
