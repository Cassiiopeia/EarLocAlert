package kr.suhsaechan.ear_loc_alert

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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

        /** 지오펜스 이벤트 전달 (이슈 #93) */
        const val ACTION_GEOFENCE_EVENT = "kr.suhsaechan.ear_loc_alert.GEOFENCE_EVENT"

        /** 지오펜스 등록 동기화 (이슈 #93) */
        const val ACTION_SYNC_GEOFENCES = "kr.suhsaechan.ear_loc_alert.SYNC_GEOFENCES"

        const val EXTRA_ENTERED = "entered"
        const val EXTRA_PROXIMITY_IDS = "proximity_ids"
        const val EXTRA_PLACE_IDS = "place_ids"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        const val EXTRA_GEOFENCES = "geofences"

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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // 서비스가 살아있는지가 알림 발화의 전제다 — 죽은 구간을
        // 시간순으로 확인할 수 있어야 한다 (이슈 #95)
        DiagnosticLog.write(this, "watch", "감시 서비스 생성")

        // 엔진이 저장된 장소로 등록을 복원하면 그대로 OS 에 밀어넣는다 (이슈 #93).
        // **재부팅 후 앱을 켜지 않아도 감시가 되살아나는 지점이다** — OS 는
        // 재부팅 시 지오펜스를 잃고, 예전에는 앱이 켜져야만 다시 등록됐다.
        engine.onSyncRequested = { fences -> applyGeofences(fences) }

        // 엔진을 먼저 띄운다 — 이벤트가 오기 전에 준비되어야 한다.
        // 부팅 중 도착한 요청은 WatchEngine 이 큐에 담았다가 흘려보낸다.
        engine.start()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_WATCH -> {
                endAlert()
                stopPreciseTracking()
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

        when (intent?.action) {
            ACTION_GEOFENCE_EVENT -> handleGeofenceEvent(intent)
            ACTION_SYNC_GEOFENCES -> handleSyncGeofences(intent)
        }

        // 프로세스가 죽어도 OS 가 되살린다 — 감시가 조용히 사라지면 안 된다
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeoutTask)
        handler.removeCallbacks(preciseTimeoutTask)
        stopPreciseTracking()
        engine.stop()
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

    // ------------------------------------------------------------ 지오펜스 처리

    /** 앱이 보낸 등록 목록을 OS 에 반영한다 (이슈 #93) */
    private fun handleSyncGeofences(intent: Intent) {
        @Suppress("UNCHECKED_CAST", "DEPRECATION")
        val fences = intent.getSerializableExtra(EXTRA_GEOFENCES)
            as? ArrayList<HashMap<String, Any?>> ?: return
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

        // 등록 개수가 0 이면 어떤 도착도 감지되지 않는다 (이슈 #95)
        DiagnosticLog.write(
            this,
            "watch",
            "네이티브 지오펜스 등록 ${lastRegisteredIds.size}건 (요청 ${fences.size}건)",
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
        val latitude =
            if (intent.hasExtra(EXTRA_LATITUDE)) intent.getDoubleExtra(EXTRA_LATITUDE, 0.0)
            else null
        val longitude =
            if (intent.hasExtra(EXTRA_LONGITUDE)) intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0)
            else null

        if (proximityIds.isNotEmpty()) {
            if (entered) startPreciseTracking(proximityIds)
            else stopPreciseTrackingIfIdle(proximityIds)
        }

        for (placeId in placeIds) {
            engine.evaluateOsTransition(placeId, entered, latitude, longitude) { decision ->
                if (decision.shouldAlert) beginAlert(decision)
            }
        }
    }

    // ------------------------------------------------------------ 정밀 감시

    private fun startPreciseTracking(placeIds: List<String>) {
        proximityPlaces += placeIds
        handler.removeCallbacks(preciseTimeoutTask)
        handler.postDelayed(preciseTimeoutTask, PRECISE_TIMEOUT_MS)
        if (tracker.isRunning) return

        DiagnosticLog.write(this, "precise", "정밀 감시 시작 대상=${proximityPlaces.size}건")

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
            DiagnosticLog.write(this, "precise", "정밀 감시 종료")
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
            DiagnosticLog.write(this, "alert", "이미 울리는 중 — 중복 발화 무시")
            return
        }
        alerting = true

        DiagnosticLog.write(
            this,
            "alert",
            "알림 시작 place=${decision.placeName} " +
                "direction=${decision.direction} " +
                "(오버레이권한=${Settings.canDrawOverlays(this)})",
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
        handler.removeCallbacks(timeoutTask)
        stopVibration()
        if (timedOut) {
            DiagnosticLog.write(this, "alert", "알림 시간 초과 — 진동 중단, 알림은 남긴다")
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
            val manager = getSystemService(NotificationManager::class.java) ?: return
            manager.notify(
                ARRIVAL_NOTIFICATION_ID,
                buildArrivalNotification(decision, ongoing = true),
            )
        } catch (error: Exception) {
            // 알림 권한이 없으면 여기서 막힌다 — 진동과 화면 승격은 계속된다.
            // 무엇이 막혔는지는 남긴다. 아무것도 안 뜨는 이유가 이것일 수 있다
            DiagnosticLog.write(this, "alert", "알림 발행 실패 $error")
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
        }
    }

    private fun createArrivalChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(ARRIVAL_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            ARRIVAL_CHANNEL_ID,
            "도착·출발 알림",
            // 헤드업으로 뜨려면 HIGH 이상이어야 한다
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "등록한 장소에 도착하거나 떠날 때 알립니다"
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
        val title = decision?.placeName?.takeIf { it.isNotBlank() } ?: "위치 알림"
        val body = if (decision?.direction == "exit") "떠났습니다" else "도착했습니다"
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
            DiagnosticLog.write(this, "alert", "진동 시작 실패 $error")
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
                "화면 승격 생략 — 다른 앱 위에 표시 권한 없음 (알림은 발행됨)",
            )
            return
        }
        val intent = launchIntent() ?: return
        try {
            startActivity(intent)
            DiagnosticLog.write(this, "alert", "화면 승격 요청 완료")
        } catch (error: Exception) {
            // Android 10+ 는 권한이 있어도 백그라운드 액티비티 시작을 막을 수
            // 있다. 그 경우 전체화면 인텐트와 알림이 남는다
            DiagnosticLog.write(this, "alert", "화면 승격 차단됨 $error")
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
