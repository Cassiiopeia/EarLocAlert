package kr.suhsaechan.ear_loc_alert

import android.location.Location
import java.util.Calendar

/**
 * 네이티브가 아는 감시 장소 한 곳 (이슈 #260)
 *
 * 지오펜스 등록 맵(`GeofenceRegistrar.sync` 가 받는 것)에서 만든다.
 * **왜 필요한가** — 중간 단계 위치 감시가 "이 위치가 근접 원 안인가"를
 * 앱 isolate 를 거치지 않고 바로 가려야 하고, 알림 시간대 밖이면 아예
 * 켜지 않아야 배터리를 아낄 수 있다. 판정(알림 여부)은 여전히 Dart 의
 * 몫이고, 여기서는 **감시를 켤지 말지**만 정한다.
 */
data class WatchPlace(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Float,
    val proximityRadiusMeters: Float,
    /** 중간 단계 감시를 켜는 바깥 원. 0 이면 이 장소는 중간 단계를 쓰지 않는다 */
    val outerRadiusMeters: Float,
    val windows: List<ScheduleWindow>,
) {

    /**
     * 알림 시간대 하나. Dart `AlertSchedule` 과 같은 규칙이다.
     *
     * 요일은 ISO(월=1 ~ 일=7), 시각은 자정 기준 분이다.
     */
    data class ScheduleWindow(
        val days: Set<Int>,
        val startMinute: Int,
        val endMinute: Int,
    ) {
        private val crossesMidnight: Boolean get() = startMinute > endMinute

        /** [calendar] 의 로컬 시각에 이 창이 열려 있는가. 구간은 `[start, end)` */
        fun isActiveAt(calendar: Calendar): Boolean {
            val minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
            val today = isoWeekday(calendar)
            if (!crossesMidnight) {
                return today in days && minute >= startMinute && minute < endMinute
            }
            // 자정을 넘기는 창 — 요일은 창이 시작된 날 기준이다
            if (minute >= startMinute) return today in days
            if (minute < endMinute) {
                val yesterday = if (today == 1) 7 else today - 1
                return yesterday in days
            }
            return false
        }
    }

    /** 지금부터 [marginMinutes] 안에 알림 시간대가 열리거나 이미 열려 있는가 */
    fun isScheduleActive(nowMs: Long, marginMinutes: Int): Boolean {
        // 창이 없으면 항상 활성이다 — Dart `isScheduleActive` 와 같은 규약
        if (windows.isEmpty()) return true
        val now = Calendar.getInstance().apply { timeInMillis = nowMs }
        val ahead = Calendar.getInstance().apply { timeInMillis = nowMs + marginMinutes * 60_000L }
        return windows.any { it.isActiveAt(now) || it.isActiveAt(ahead) }
    }

    /** 장소 중심까지의 거리(m) */
    fun distanceTo(latitude: Double, longitude: Double): Float {
        val out = FloatArray(1)
        Location.distanceBetween(this.latitude, this.longitude, latitude, longitude, out)
        return out[0]
    }

    /** 로그용 요약 — 아이디는 앞 8자만 남긴다(다른 로그와 같은 표기) */
    val shortId: String get() = id.take(8)

    companion object {

        private fun isoWeekday(calendar: Calendar): Int =
            // Calendar 는 일요일이 1 이다 → ISO 월=1 ~ 일=7 로 맞춘다
            (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1

        /**
         * 등록 맵에서 만든다. 필수 값이 없으면 null.
         *
         * `scheduleWindows` 는 `"12345,465,600;67,600,700"` 형태의 문자열이다 —
         * 맵이 SharedPreferences 에 JSON 으로 저장되는 경로(`WatchState`)를
         * 중첩 구조 없이 건너가게 하려는 것이다.
         */
        fun fromMap(fence: Map<String, Any?>): WatchPlace? {
            val id = fence["placeId"] as? String ?: return null
            val lat = (fence["latitude"] as? Number)?.toDouble() ?: return null
            val lng = (fence["longitude"] as? Number)?.toDouble() ?: return null
            val radius = (fence["radiusMeters"] as? Number)?.toFloat() ?: return null
            val proximity = (fence["proximityRadiusMeters"] as? Number)?.toFloat() ?: return null
            val outer = (fence["outerRadiusMeters"] as? Number)?.toFloat() ?: 0f
            return WatchPlace(
                id = id,
                latitude = lat,
                longitude = lng,
                radiusMeters = radius,
                proximityRadiusMeters = proximity,
                outerRadiusMeters = outer,
                windows = parseWindows(fence["scheduleWindows"] as? String),
            )
        }

        fun parseWindows(raw: String?): List<ScheduleWindow> {
            if (raw.isNullOrBlank()) return emptyList()
            return raw.split(';').mapNotNull { part ->
                val fields = part.split(',')
                if (fields.size != 3) return@mapNotNull null
                val days = fields[0].mapNotNull { it.digitToIntOrNull() }.toSet()
                val start = fields[1].toIntOrNull() ?: return@mapNotNull null
                val end = fields[2].toIntOrNull() ?: return@mapNotNull null
                ScheduleWindow(days, start, end)
            }
        }
    }
}
