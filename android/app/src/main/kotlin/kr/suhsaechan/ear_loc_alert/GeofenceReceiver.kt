package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
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
    }

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return

        val entered = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> true
            Geofence.GEOFENCE_TRANSITION_EXIT -> false
            // dwell 은 등록하지 않는다
            else -> return
        }

        val triggered = event.triggeringGeofences ?: return
        if (triggered.isEmpty()) return

        // 한 이벤트에 여러 지오펜스가 묶여 올 수 있다. 근접과 실제를 나눠
        // 담아 서비스가 각각 다르게 처리하게 한다 — 근접은 정밀 감시를
        // 켜고 끄는 신호이고, 실제는 판정 대상이다.
        val proximityIds = ArrayList<String>()
        val placeIds = ArrayList<String>()
        for (fence in triggered) {
            val id = fence.requestId
            if (GeofenceRegistrar.isProximity(id)) {
                proximityIds += GeofenceRegistrar.placeIdOf(id)
            } else {
                placeIds += id
            }
        }

        val location = event.triggeringLocation
        val forward = Intent(context, AlertWatchService::class.java)
            .setAction(AlertWatchService.ACTION_GEOFENCE_EVENT)
            .putExtra(AlertWatchService.EXTRA_ENTERED, entered)
            .putStringArrayListExtra(AlertWatchService.EXTRA_PROXIMITY_IDS, proximityIds)
            .putStringArrayListExtra(AlertWatchService.EXTRA_PLACE_IDS, placeIds)
        if (location != null) {
            forward.putExtra(AlertWatchService.EXTRA_LATITUDE, location.latitude)
            forward.putExtra(AlertWatchService.EXTRA_LONGITUDE, location.longitude)
        }

        try {
            // 서비스가 죽어 있어도 여기서 살아난다 — 이것이 "앱을 한 번도
            // 켜지 않아도 울린다"를 성립시키는 지점이다
            context.startForegroundService(forward)
        } catch (error: Exception) {
            // 백그라운드 서비스 시작 제한에 걸렸다. 다음 이벤트에서 재시도된다
        }
    }
}
