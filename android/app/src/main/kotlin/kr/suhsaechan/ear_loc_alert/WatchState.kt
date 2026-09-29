package kr.suhsaechan.ear_loc_alert

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * 감시 상태의 네이티브 사본 (이슈 #159)
 *
 * **왜 필요한가** — 지오펜스 등록의 원본은 Dart(Drift)에 있고, 엔진이 떠야만
 * 읽을 수 있다. 그런데 OS 가 등록을 조용히 잃는 경우(앱 교체, 재부팅, Play
 * 서비스 정리)에는 엔진 없이도 즉시 복구할 수 있어야 한다. 마지막으로 OS 에
 * 밀어넣은 목록을 여기 남겨 두면 서비스가 죽어 있어도 복구가 가능하다.
 *
 * 시각 기록은 진단용이다. "조용한 것"과 "죽은 것"을 가르려면 마지막 등록과
 * 마지막 수신이 언제였는지 알아야 한다.
 */
object WatchState {
    private const val PREFS = "watch_state"
    private const val KEY_FENCES = "fences"
    private const val KEY_REGISTERED_AT = "registered_at"
    private const val KEY_EVENT_AT = "event_at"
    private const val KEY_EXIT_LOGGED_AT = "exit_logged_at"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** 마지막으로 OS 에 밀어넣은 목록을 저장한다. 빈 목록이면 지운다 */
    fun saveFences(context: Context, fences: List<Map<String, Any?>>) {
        val array = JSONArray()
        for (fence in fences) {
            val json = JSONObject()
            for ((key, value) in fence) {
                if (value != null) json.put(key, value)
            }
            array.put(json)
        }
        prefs(context).edit().putString(KEY_FENCES, array.toString()).apply()
    }

    /** 저장된 목록. 없거나 손상됐으면 빈 목록 */
    fun loadFences(context: Context): List<Map<String, Any?>> {
        val raw = prefs(context).getString(KEY_FENCES, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { index ->
                val json = array.getJSONObject(index)
                json.keys().asSequence().associateWith { key -> json.get(key) }
            }
        } catch (error: Exception) {
            emptyList()
        }
    }

    fun markRegistered(context: Context, nowMs: Long = System.currentTimeMillis()) {
        prefs(context).edit().putLong(KEY_REGISTERED_AT, nowMs).apply()
    }

    fun markEvent(context: Context, nowMs: Long = System.currentTimeMillis()) {
        prefs(context).edit().putLong(KEY_EVENT_AT, nowMs).apply()
    }

    fun registeredAt(context: Context): Long = prefs(context).getLong(KEY_REGISTERED_AT, 0L)

    fun eventAt(context: Context): Long = prefs(context).getLong(KEY_EVENT_AT, 0L)

    fun exitLoggedAt(context: Context): Long = prefs(context).getLong(KEY_EXIT_LOGGED_AT, 0L)

    fun markExitLogged(context: Context, timestampMs: Long) {
        prefs(context).edit().putLong(KEY_EXIT_LOGGED_AT, timestampMs).apply()
    }

    /** "3h12m ago" 같은 표기. 기록이 없으면 "never" */
    fun agoText(sinceMs: Long, nowMs: Long = System.currentTimeMillis()): String {
        if (sinceMs <= 0L) return "never"
        val minutes = ((nowMs - sinceMs) / 60_000L).coerceAtLeast(0L)
        return "${minutes / 60}h${minutes % 60}m ago"
    }
}
