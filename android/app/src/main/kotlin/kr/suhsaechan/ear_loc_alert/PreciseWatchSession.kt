package kr.suhsaechan.ear_loc_alert

import android.os.SystemClock

/**
 * 정밀 감시 1회 상태: Dart 판정 생략 근거(마지막 판정 시각·장소별 안/밖), 통계 (이슈 #318)
 * 시작마다 [reset]. 판정 여부 규칙은 [PreciseWatchPolicy.shouldEvaluate]
 */
class PreciseWatchSession {

    var fixCount = 0
        private set
    var evaluatedCount = 0
        private set
    var skippedCount = 0
        private set

    private var startedElapsedMs = 0L

    /** 마지막 판정 시각 (elapsedRealtime). 0 = 이번 세션 판정 없음 */
    private var lastEvaluationElapsedMs = 0L

    /** 마지막으로 Dart 에 넘긴 위치 기준 장소별 실제 반경 안쪽 여부 */
    private val lastEvaluatedInsideById = mutableMapOf<String, Boolean>()

    fun reset() {
        fixCount = 0
        evaluatedCount = 0
        skippedCount = 0
        startedElapsedMs = SystemClock.elapsedRealtime()
        lastEvaluationElapsedMs = 0L
        lastEvaluatedInsideById.clear()
    }

    /**
     * 위치 1건 기록 > Dart 로 넘길지 반환
     * 안/밖 비교는 모든 장소 대상 (시간대 밖 장소도 Dart 상태 추적이 끊기지 않게)
     */
    fun recordFix(
        places: List<WatchPlace>,
        nearestTargetBoundaryMeters: Float?,
        latitude: Double,
        longitude: Double,
    ): Boolean {
        fixCount++
        val nowElapsedMs = SystemClock.elapsedRealtime()
        val insideById = places.associate { it.id to (it.distanceTo(latitude, longitude) <= it.radiusMeters) }
        val hasAnySideChanged = insideById.any { (id, isInside) ->
            lastEvaluatedInsideById[id]?.let { it != isInside } ?: true
        }
        val shouldEvaluate = PreciseWatchPolicy.shouldEvaluate(
            isFirstFix = lastEvaluationElapsedMs == 0L,
            nearestTargetBoundaryMeters = nearestTargetBoundaryMeters,
            hasAnySideChanged = hasAnySideChanged,
            millisecondsSinceLastEvaluation = nowElapsedMs - lastEvaluationElapsedMs,
        )
        if (shouldEvaluate) {
            evaluatedCount++
            lastEvaluationElapsedMs = nowElapsedMs
            lastEvaluatedInsideById.clear()
            lastEvaluatedInsideById.putAll(insideById)
        } else {
            skippedCount++
        }
        return shouldEvaluate
    }

    /** 로그용 요약: fixes=12 evaluated=5 skipped=7 ran_s=340 */
    fun summary(): String =
        "fixes=$fixCount evaluated=$evaluatedCount skipped=$skippedCount " +
            "ran_s=${(SystemClock.elapsedRealtime() - startedElapsedMs) / 1000}"
}
