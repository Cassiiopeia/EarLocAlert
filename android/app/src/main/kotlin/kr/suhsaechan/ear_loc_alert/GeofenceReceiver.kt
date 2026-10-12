package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import android.os.SystemClock
import com.google.android.gms.location.GeofencingEvent

/**
 * 지오펜스 이벤트 수신 (이슈 #93)
 *
 * **여기서 WorkManager 를 쓰지 않는 것이 이 이슈의 핵심이다.** 큐에 넣는
 * 순간 즉시 실행 쿼터와 Doze 제한 아래로 들어가고, 작업 체인이 한 번
 * 실패하면 이후 이벤트가 조용히 사라진다. 받은 자리에서 감시 서비스로
 * 넘긴다 — 서비스는 대개 이미 떠 있고, 없으면 여기서 띄운다.
 */
class GeofenceReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_GEOFENCE_EVENT = "kr.suhsaechan.ear_loc_alert.GEOFENCE_EVENT"

        /**
         * 직전 이벤트를 받은 시각(elapsedRealtime).
         *
         * 이벤트 사이 간격을 남기려는 용도다 — "OS 가 얼마나 오래 조용했다가
         * 한꺼번에 전달했는가"가 지연 원인을 가르는 단서다 (이슈 #260).
         */
        @Volatile
        private var lastEventElapsedMs: Long = 0L
    }

    override fun onReceive(context: Context, intent: Intent) {
        // **이 한 줄이 이 로그의 존재 이유다** (이슈 #95).
        // "OS 가 도착을 감지해 우리에게 알렸는가"를 가르는 지점이라,
        // 알림이 안 왔을 때 가장 먼저 봐야 하는 기록이다.
        DiagnosticLog.write(context, "receiver", "geofence broadcast received")
        // 마지막 수신 시각 — 주기 점검이 "신호가 언제부터 없었나"를 남기는 근거 (이슈 #159)
        WatchState.markEvent(context)

        val event = GeofencingEvent.fromIntent(intent)
        if (event == null) {
            DiagnosticLog.write(context, "receiver", "event parse failed, ignored")
            return
        }
        if (event.hasError()) {
            DiagnosticLog.write(context, "receiver", "event error code=${event.errorCode}")
            return
        }

        val entered = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> true
            Geofence.GEOFENCE_TRANSITION_EXIT -> false
            // dwell 은 등록하지 않는다
            else -> {
                DiagnosticLog.write(
                    context,
                    "receiver",
                    "unhandled transition type=${event.geofenceTransition}",
                )
                return
            }
        }

        val triggered = event.triggeringGeofences
        if (triggered.isNullOrEmpty()) {
            DiagnosticLog.write(context, "receiver", "no triggering geofence, ignored")
            return
        }

        // 한 이벤트에 여러 지오펜스가 묶여 올 수 있다. 근접과 실제를 나눠
        // 담아 서비스가 각각 다르게 처리하게 한다 — 근접은 정밀 감시를
        // 켜고 끄는 신호이고, 실제는 판정 대상이다.
        val proximityIds = ArrayList<String>()
        val outerIds = ArrayList<String>()
        val placeIds = ArrayList<String>()
        for (fence in triggered) {
            val id = fence.requestId
            when {
                GeofenceRegistrar.isProximity(id) -> proximityIds += GeofenceRegistrar.placeIdOf(id)
                // 바깥 원은 중간 단계 위치 감시를 켜고 끄는 신호다 (이슈 #260)
                GeofenceRegistrar.isOuter(id) -> outerIds += GeofenceRegistrar.placeIdOf(id)
                else -> placeIds += id
            }
        }

        val location = event.triggeringLocation
        val forward = Intent(context, AlertWatchService::class.java)
            .setAction(AlertWatchService.ACTION_GEOFENCE_EVENT)
            .putExtra(AlertWatchService.EXTRA_ENTERED, entered)
            .putStringArrayListExtra(AlertWatchService.EXTRA_PROXIMITY_IDS, proximityIds)
            .putStringArrayListExtra(AlertWatchService.EXTRA_OUTER_IDS, outerIds)
            .putStringArrayListExtra(AlertWatchService.EXTRA_PLACE_IDS, placeIds)
        if (location != null) {
            forward.putExtra(AlertWatchService.EXTRA_LATITUDE, location.latitude)
            forward.putExtra(AlertWatchService.EXTRA_LONGITUDE, location.longitude)
        }

        DiagnosticLog.write(
            context,
            "receiver",
            "${if (entered) "ENTER" else "EXIT"} proximity=${proximityIds.size} " +
                "outer=${outerIds.size} " +
                "actual=${placeIds.size} ids=${placeIds.joinToString(",")} " +
                "lat=${location?.latitude} lng=${location?.longitude}",
        )

        // **지연 원인을 사후에 가르기 위한 상세 기록** (이슈 #260).
        // 이벤트가 담고 온 위치가 얼마나 오래됐는지(`fix_age_s`), 직전 이벤트
        // 이후 얼마나 조용했는지, 그때 화면·Doze·절전·배터리가 어땠는지를 남긴다.
        // 2026-10-13 소만사 도착 알림이 늦었을 때 이 값이 없어 원인을
        // 추정으로만 말할 수 있었다.
        val nowElapsed = SystemClock.elapsedRealtime()
        val sinceLastEventS =
            if (lastEventElapsedMs == 0L) "first" else ((nowElapsed - lastEventElapsedMs) / 1000).toString()
        lastEventElapsedMs = nowElapsed
        val fixAgeS = location?.let {
            // 위치가 만들어진 뒤 지난 시간 — 오래될수록 "그 자리에서 났던 이벤트"가 아니다
            ((SystemClock.elapsedRealtimeNanos() - it.elapsedRealtimeNanos) / 1_000_000_000L).toString()
        } ?: "none"
        DiagnosticLog.write(
            context,
            "receiver",
            "detail transition=${if (entered) "ENTER" else "EXIT"} " +
                "fences=${triggered.joinToString(",") { it.requestId.take(8) + fenceKind(it.requestId) }} " +
                "fix_age_s=$fixAgeS fix_acc_m=${location?.accuracy} fix_provider=${location?.provider} " +
                "since_last_event_s=$sinceLastEventS ${DeviceState.snapshot(context)}",
        )

        try {
            // 서비스가 죽어 있어도 여기서 살아난다 — 이것이 "앱을 한 번도
            // 켜지 않아도 울린다"를 성립시키는 지점이다
            context.startForegroundService(forward)
        } catch (error: Exception) {
            // 백그라운드 서비스 시작 제한에 걸렸다. 다음 이벤트에서 재시도된다.
            // 기록은 남긴다 — 여기서 막히면 알림이 통째로 사라진다 (이슈 #95)
            DiagnosticLog.write(context, "receiver", "service start failed $error")
        }
    }

    /** 로그용 — 지오펜스 id 가 어느 원인지 접미사로 남긴다 */
    private fun fenceKind(requestId: String): String = when {
        GeofenceRegistrar.isProximity(requestId) -> "#proximity"
        GeofenceRegistrar.isOuter(requestId) -> "#outer"
        else -> "#actual"
    }
}
