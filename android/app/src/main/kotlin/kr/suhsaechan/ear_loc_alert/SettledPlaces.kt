package kr.suhsaechan.ear_loc_alert

/**
 * 처리 완료 장소: 알림 뒤 표시, 해제 조건 3개(반대 OS 전이, 반대쪽 위치, 시간대 종료) (이슈 #318)
 * 표시·해제 결과만 돌려줌 > 기록은 호출부가 DiagnosticLog 로 남김
 */
class SettledPlaces {

    private val settledIds = mutableSetOf<String>()

    val placeIds: Set<String> get() = settledIds

    /** enter·exit 전용 장소만 표시. 새로 표시됐으면 true */
    fun settle(place: WatchPlace): Boolean =
        PreciseWatchPolicy.shouldSettleAfterAlert(place) && settledIds.add(place.id)

    /** 알림 방향의 반대 OS 전이 (enter 알림 > EXIT, exit 알림 > ENTER) > 해제. 해제됐으면 true */
    fun releaseByTransition(place: WatchPlace, entered: Boolean): Boolean {
        if (place.id !in settledIds) return false
        val isOppositeTransition = when (place.direction) {
            WatchPlace.DIRECTION_ENTER -> !entered
            WatchPlace.DIRECTION_EXIT -> entered
            else -> true
        }
        return isOppositeTransition && settledIds.remove(place.id)
    }

    /** 위치가 알림 반대쪽으로 경계를 확실히 넘은 장소 > 해제 (OS 전이가 늦거나 없을 때 대비) */
    fun releaseByFix(
        places: List<WatchPlace>,
        latitude: Double,
        longitude: Double,
        accuracyMeters: Float,
    ): List<WatchPlace> = releaseWhere(places) {
        PreciseWatchPolicy.hasLeftSettledSide(it, it.distanceTo(latitude, longitude), accuracyMeters)
    }

    /** 시간대가 닫힌 장소 > 해제 (다음 시간대에 다시 감시) */
    fun releaseOutsideSchedule(places: List<WatchPlace>, nowMs: Long): List<WatchPlace> =
        releaseWhere(places) { !it.isScheduleActive(nowMs, PreciseWatchPolicy.SCHEDULE_MARGIN_MINUTES) }

    /** 장소 목록 갱신 시 사라진 장소 정리 */
    fun retainAll(knownIds: Set<String>) {
        settledIds.retainAll(knownIds)
    }

    private fun releaseWhere(places: List<WatchPlace>, shouldRelease: (WatchPlace) -> Boolean): List<WatchPlace> {
        val released = places.filter { it.id in settledIds && shouldRelease(it) }
        settledIds -= released.map { it.id }.toSet()
        return released
    }
}
