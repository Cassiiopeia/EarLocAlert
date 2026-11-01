package kr.suhsaechan.ear_loc_alert

import kotlin.math.abs
import kotlin.math.max

/**
 * 정밀 감시 정책: 켤 대상 선정, 측정 주기, Dart 판정 생략 여부 (이슈 #318)
 * 알림이 날 수 없는 구간(시간대 밖·이미 울린 장소·경계에서 먼 위치)의 GPS·판정만 줄임
 */
object PreciseWatchPolicy {

    /** 알림 시간대가 열리기 이만큼 전부터 정밀 감시 대상 (중간 단계와 같은 여유) */
    const val SCHEDULE_MARGIN_MINUTES = 30

    /**
     * 주기 계산에 쓰는 최악 이동 속도 (126km/h).
     * 지금 속도가 아니라 최악값 기준 > 정지했다 갑자기 차를 타도 경계 전에 측정 2번 이상
     */
    private const val WORST_CASE_SPEED_METERS_PER_SECOND = 35.0

    /** 경계까지 남은 거리(m) 하한 > 측정 주기. 위에서부터 첫 일치 */
    private val INTERVAL_BY_BOUNDARY_DISTANCE = listOf(
        3_000f to 40_000L,
        1_500f to 20_000L,
        700f to 10_000L,
    )

    /** 경계 근처 기본 주기 (#93 의 원래 값) */
    const val NEAR_INTERVAL_MILLISECONDS = 5_000L

    /** 이 거리(m) 안이면 위치마다 Dart 판정 (5초 주기 구간과 같은 경계) */
    private const val EVALUATE_ALWAYS_WITHIN_METERS = 700f

    /** 판정을 건너뛰더라도 이 간격마다 한 번은 판정 (상태·로그 공백 방지) */
    const val EVALUATION_HEARTBEAT_MILLISECONDS = 60_000L

    /** 처리 완료 해제 시 경계 바깥/안쪽으로 이만큼은 확실히 넘어야 함(m) — 측정 오차 흡수 */
    private const val SETTLED_RELEASE_MIN_MARGIN_METERS = 50f

    /**
     * 정밀 감시가 필요한 장소: 근접 원 안 + 시간대 활성(여유 포함) + 처리 완료 아님
     * 시간대 밖 장소는 Dart 판정기가 알림을 막으므로(outside_schedule) GPS 가 결과에 영향 없음
     */
    fun eligibleTargets(
        places: List<WatchPlace>,
        proximityPlaceIds: Set<String>,
        settledPlaceIds: Set<String>,
        nowMs: Long,
    ): List<WatchPlace> = places.filter {
        it.id in proximityPlaceIds &&
            it.id !in settledPlaceIds &&
            it.isScheduleActive(nowMs, SCHEDULE_MARGIN_MINUTES)
    }

    /** 실제 반경 경계까지 거리(m). 안쪽이든 바깥쪽이든 양수 */
    fun distanceToBoundary(place: WatchPlace, latitude: Double, longitude: Double): Float =
        abs(place.distanceTo(latitude, longitude) - place.radiusMeters)

    /**
     * 가장 가까운 경계 거리(m) > 측정 주기
     * 표 값은 최악 속도로도 경계 도달 전 측정 2번 이상 (예: 3km / 35m/s = 86초 > 40초 × 2)
     */
    fun intervalFor(nearestBoundaryMeters: Float?): Long {
        if (nearestBoundaryMeters == null) return NEAR_INTERVAL_MILLISECONDS
        val interval = INTERVAL_BY_BOUNDARY_DISTANCE
            .firstOrNull { (minimumMeters, _) -> nearestBoundaryMeters >= minimumMeters }
            ?.second ?: return NEAR_INTERVAL_MILLISECONDS
        // 표를 잘못 고쳐도 최악 속도 기준 2번 측정은 보장
        val safeLimitMs = (nearestBoundaryMeters / WORST_CASE_SPEED_METERS_PER_SECOND / 2 * 1000).toLong()
        return max(NEAR_INTERVAL_MILLISECONDS, minOf(interval, safeLimitMs))
    }

    /**
     * 정밀 감시 위치 1건을 Dart 로 넘길지
     * 넘김 조건 4개: 세션 첫 위치, 대상 경계 근처, 어느 장소든 안/밖 바뀜, 하트비트 경과
     */
    fun shouldEvaluate(
        isFirstFix: Boolean,
        nearestTargetBoundaryMeters: Float?,
        hasAnySideChanged: Boolean,
        millisecondsSinceLastEvaluation: Long,
    ): Boolean {
        if (isFirstFix || hasAnySideChanged) return true
        if (nearestTargetBoundaryMeters == null || nearestTargetBoundaryMeters < EVALUATE_ALWAYS_WITHIN_METERS) return true
        return millisecondsSinceLastEvaluation >= EVALUATION_HEARTBEAT_MILLISECONDS
    }

    /**
     * 알림 뒤 다시 알릴 일이 없는 장소인가 (enter·exit 전용)
     * both 는 반대 방향 알림이 남아 있어 제외
     */
    fun shouldSettleAfterAlert(place: WatchPlace): Boolean =
        place.direction == WatchPlace.DIRECTION_ENTER || place.direction == WatchPlace.DIRECTION_EXIT

    /**
     * 처리 완료 해제 여부: 알림 방향의 반대쪽으로 경계를 확실히 넘음
     * enter 알림 > 밖으로 나감 · exit 알림 > 안으로 들어옴
     */
    fun hasLeftSettledSide(place: WatchPlace, distanceMeters: Float, accuracyMeters: Float): Boolean {
        val margin = max(accuracyMeters, SETTLED_RELEASE_MIN_MARGIN_METERS)
        return when (place.direction) {
            WatchPlace.DIRECTION_ENTER -> distanceMeters > place.radiusMeters + margin
            WatchPlace.DIRECTION_EXIT -> distanceMeters < place.radiusMeters - margin
            else -> true
        }
    }
}
