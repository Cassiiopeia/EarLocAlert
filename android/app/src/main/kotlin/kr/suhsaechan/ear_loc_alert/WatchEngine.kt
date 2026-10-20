package kr.suhsaechan.ear_loc_alert

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 감시 서비스가 보유하는 Flutter 엔진 (이슈 #93)
 *
 * **왜 상시 보유하나** — 예전 구조는 지오펜스 이벤트마다 엔진을 새로
 * 띄웠다. 엔진 부팅에는 실패 지점이 셋 있고(콜백 핸들 조회·콜백 정보
 * 조회·엔진 생성), 그 실패가 이벤트마다 재발한다. 한 번 띄워 들고 있으면
 * 그 실패 지점이 통째로 사라진다. **이것이 이 이슈의 근본 수정이다.**
 *
 * 판정은 전부 Dart 에 있다. 이 클래스는 채널을 여닫고 값을 옮길 뿐
 * 어떤 판정도 하지 않는다 (docs/03-DOMAIN.md 규칙 5).
 */
class WatchEngine(private val context: Context) {

    companion object {
        private const val CHANNEL = "kr.suhsaechan.ear_loc_alert/watch_engine"

        /**
         * **`main.dart` 를 가리킨다** (이슈 #93).
         *
         * 구현 파일(`watch_engine_entrypoint.dart`)을 직접 가리켰더니 엔진이
         * 뜨지 않았다 — Dart 컴파일러가 **도달 불가능한 라이브러리를 번들에서
         * 제외**하기 때문이다. `@pragma('vm:entry-point')` 는 함수의 트리셰이킹만
         * 막고 라이브러리 누락은 막지 못한다.
         *
         * ```
         * Dart_LookupLibrary: library '...watch_engine_entrypoint.dart' not found
         * Could not create root isolate
         * ```
         *
         * `main.dart` 는 항상 번들에 있으므로 거기 얇은 위임 함수를 두었다.
         */
        private const val ENTRYPOINT_LIBRARY = "package:ear_loc_alert/main.dart"
        private const val ENTRYPOINT = "watchEngineMain"

        // 엔진 생성 실패 후 재시도 최소 간격 (1분) — 판정 요청마다 블로킹 초기화를 반복하지 않게
        private const val RESTART_MIN_INTERVAL_MS = 60_000L

        // 준비 신호 전 판정 대기 최대 건수 — 넘으면 오래된 것부터 버림
        private const val PENDING_MAX_COUNT = 50
    }

    private val handler = Handler(Looper.getMainLooper())

    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false

    /** 서비스가 [stop] 을 불렀다 — 이후 판정 요청으로 엔진을 다시 띄우지 않음 */
    private var isStopped = false

    /** 마지막 시작 시도 시각 (elapsedRealtime ms, 0 은 시도 없음) */
    private var lastStartAttemptElapsedMs = 0L

    /** 엔진 없음 로그를 실패 구간마다 1회만 남김 — 엔진이 뜨면 초기화 */
    private var hasLoggedNoEngine = false

    /**
     * Dart 가 요청한 지오펜스 복원을 서비스로 넘긴다 (이슈 #93).
     *
     * OS 는 재부팅 시 지오펜스 등록을 잃는다. 앱이 켜질 때만 등록하던
     * 구조에서는 **재부팅 후 앱을 켜지 않으면 도착을 영영 감지하지 못했다.**
     */
    var onSyncRequested: ((List<Map<String, Any?>>) -> Unit)? = null

    /**
     * 엔진 준비 전에 도착한 판정 요청.
     *
     * 서비스가 막 떠서 엔진이 부팅 중일 때 지오펜스 이벤트가 오면 여기
     * 쌓였다가 준비 직후 순서대로 흘러간다. 버리면 그 도착이 유실된다.
     */
    private val pending = mutableListOf<() -> Unit>()

    val isRunning: Boolean get() = engine != null

    /**
     * 엔진을 띄운다. 이미 떠 있으면 아무것도 하지 않는다.
     *
     * 메인 스레드에서 불러야 한다 — FlutterEngine 생성과 채널 등록이
     * 메인 루퍼를 요구한다.
     */
    fun start() {
        isStopped = false
        if (engine != null) return
        lastStartAttemptElapsedMs = SystemClock.elapsedRealtime()

        // 로더 초기화·엔진 생성 실패 모두 서비스를 죽이지 않음 > 다음 판정 요청에서 재시도 ([invoke])
        val loader = FlutterInjector.instance().flutterLoader()
        try {
            if (!loader.initialized()) {
                loader.startInitialization(context)
            }
            loader.ensureInitializationComplete(context, null)
        } catch (error: Exception) {
            DiagnosticLog.write(context, "engine", "flutter loader init failed error=$error")
            return
        }

        val created = try {
            FlutterEngine(context)
        } catch (error: Exception) {
            DiagnosticLog.write(context, "engine", "flutter engine create failed error=$error")
            return
        }

        // 채널 등록·진입점 실행 실패 > 만든 엔진 정리 후 다음 재시도에 맡김
        try {
            channel = bindChannel(created)
            created.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    ENTRYPOINT_LIBRARY,
                    ENTRYPOINT,
                ),
            )
        } catch (error: Exception) {
            DiagnosticLog.write(context, "engine", "flutter entrypoint start failed error=$error")
            channel = null
            created.destroy()
            return
        }

        engine = created
        hasLoggedNoEngine = false
    }

    private fun bindChannel(created: FlutterEngine): MethodChannel {
        val ch = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "engineReady" -> {
                    ready = true
                    if (pending.isNotEmpty()) {
                        DiagnosticLog.write(context, "engine", "ready flushed pending=${pending.size}")
                    }
                    pending.forEach { it() }
                    pending.clear()
                    result.success(null)
                }
                // 엔진이 저장된 장소로 등록 복원을 요청한다 (이슈 #93)
                "syncGeofences" -> {
                    @Suppress("UNCHECKED_CAST")
                    val fences = call.argument<List<Map<String, Any?>>>("geofences")
                        ?: emptyList()
                    onSyncRequested?.invoke(fences)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        return ch
    }

    fun stop() {
        isStopped = true
        if (pending.isNotEmpty()) {
            DiagnosticLog.write(context, "engine", "decision dropped reason=stopped count=${pending.size}")
        }
        engine?.destroy()
        engine = null
        channel = null
        ready = false
        pending.clear()
    }

    /** 엔진이 없고 정지 전이며 재시도 간격이 지났는가 */
    private fun shouldRestart(): Boolean =
        engine == null && !isStopped &&
            SystemClock.elapsedRealtime() - lastStartAttemptElapsedMs >= RESTART_MIN_INTERVAL_MS

    /** 정밀 측정 판정을 요청한다. 결과는 [onDecision] 으로 온다 */
    fun evaluatePosition(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        timestampMs: Long,
        onDecision: (AlertDecision) -> Unit,
    ) {
        invoke(
            "evaluatePosition",
            mapOf(
                "latitude" to latitude,
                "longitude" to longitude,
                "accuracyMeters" to accuracyMeters,
                "timestampMs" to timestampMs,
            ),
            onDecision,
        )
    }

    /** OS 전이 판정을 요청한다 — 정밀 감시가 죽어 있어도 도는 폴백 경로 */
    fun evaluateOsTransition(
        placeId: String,
        entered: Boolean,
        latitude: Double?,
        longitude: Double?,
        onDecision: (AlertDecision) -> Unit,
    ) {
        invoke(
            "evaluateOsTransition",
            mapOf(
                "placeId" to placeId,
                "entered" to entered,
                "latitude" to latitude,
                "longitude" to longitude,
            ),
            onDecision,
        )
    }

    private fun invoke(
        method: String,
        args: Map<String, Any?>,
        onDecision: (AlertDecision) -> Unit,
    ) {
        val task = {
            val target = channel
            if (target == null) {
                if (!hasLoggedNoEngine) {
                    hasLoggedNoEngine = true
                    DiagnosticLog.write(context, "engine", "decision skipped method=$method reason=no_engine")
                }
                onDecision(AlertDecision.none())
            } else {
                target.invokeMethod(method, args, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        onDecision(AlertDecision.fromMap(result as? Map<*, *>))
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        // 판정 실패는 알림 없음으로 떨어진다
                        DiagnosticLog.write(
                            context,
                            "engine",
                            "decision failed method=$method reason=dart_error code=$code message=$message",
                        )
                        onDecision(AlertDecision.none())
                    }

                    override fun notImplemented() {
                        DiagnosticLog.write(
                            context,
                            "engine",
                            "decision failed method=$method reason=not_implemented",
                        )
                        onDecision(AlertDecision.none())
                    }
                })
            }
        }

        // 채널 호출은 메인 스레드에서만 안전하다
        handler.post {
            // 엔진 생성이 실패했던 경우 여기서 다시 띄움 (서비스 정지 후 제외, 1분 간격)
            if (shouldRestart()) {
                DiagnosticLog.write(context, "engine", "restart requested method=$method")
                start()
            }
            when {
                ready -> task()
                engine == null -> task()
                else -> enqueue(task, method)
            }
        }
    }

    /** 준비 전 판정 보관 (최대 [PENDING_MAX_COUNT], 넘으면 가장 오래된 것 버림) */
    private fun enqueue(task: () -> Unit, method: String) {
        if (pending.isEmpty()) {
            DiagnosticLog.write(context, "engine", "decision queued until ready method=$method")
        }
        if (pending.size >= PENDING_MAX_COUNT) {
            pending.removeAt(0)
            DiagnosticLog.write(context, "engine", "decision dropped reason=queue_full max=$PENDING_MAX_COUNT")
        }
        pending += task
    }
}

/**
 * Dart 가 돌려준 판정 결과.
 *
 * 키 이름이 `lib/app/background/alert_decision.dart` 의 `toMap()` 과
 * 계약이다. 한쪽만 바꾸면 알림이 조용히 사라진다.
 */
data class AlertDecision(
    val shouldAlert: Boolean,
    val placeId: String?,
    val placeName: String?,
    val direction: String?,
    val soundEnabled: Boolean,
    /**
     * 사용자가 설정한 진동 세기 (이슈 #103).
     *
     * **0 은 "설정 없음"이다** — 기존 기본 진동으로 떨어진다. 설정을 읽는
     * 자리는 Dart 한 곳뿐이고, 여기는 받은 값을 쓰기만 한다.
     */
    val vibrationAmplitude: Int,
    val vibrationPulseMs: Int,
) {
    companion object {
        fun none() = AlertDecision(false, null, null, null, true, 0, 0)

        fun fromMap(map: Map<*, *>?): AlertDecision {
            if (map == null) return none()
            return AlertDecision(
                shouldAlert = map["shouldAlert"] as? Boolean ?: false,
                placeId = map["placeId"] as? String,
                placeName = map["placeName"] as? String,
                direction = map["direction"] as? String,
                soundEnabled = map["soundEnabled"] as? Boolean ?: true,
                vibrationAmplitude = (map["vibrationAmplitude"] as? Number)?.toInt() ?: 0,
                vibrationPulseMs = (map["vibrationPulseMs"] as? Number)?.toInt() ?: 0,
            )
        }
    }
}
