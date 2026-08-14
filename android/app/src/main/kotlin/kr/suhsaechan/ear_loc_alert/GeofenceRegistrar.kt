package kr.suhsaechan.ear_loc_alert

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * OS 지오펜스 등록/해제 (이슈 #93)
 *
 * **왜 직접 등록하나** — native_geofence 는 이벤트를 WorkManager 로 넘긴다.
 * 즉시 실행 쿼터가 소진되면 일반 작업으로 강등되어 Doze 제한을 받고,
 * 작업 체인이 한 번 실패하면 이후 모든 이벤트가 실행되지 않는다.
 * PendingIntent 목적지가 그 패키지 리시버로 하드코딩돼 있어 가로챌 수도
 * 없다. 그래서 등록을 앱이 가져온다.
 *
 * **장소마다 둘 등록한다.** 실제 반경(`{placeId}`)과 근접 반경
 * (`{placeId}#proximity`). 근접은 정밀 감시를 켜는 트리거이고, 실제는
 * 정밀 감시가 실패했을 때의 폴백이다. 하나만 두면 한쪽이 죽을 때 발화가
 * 통째로 사라진다.
 */
class GeofenceRegistrar(private val context: Context) {

    companion object {
        /** 근접 지오펜스 id 접미사 — 실제 반경과 구분하는 유일한 표식 */
        const val PROXIMITY_SUFFIX = "#proximity"

        fun placeIdOf(geofenceId: String): String =
            geofenceId.removeSuffix(PROXIMITY_SUFFIX)

        fun isProximity(geofenceId: String): Boolean =
            geofenceId.endsWith(PROXIMITY_SUFFIX)
    }

    private val client: GeofencingClient by lazy {
        LocationServices.getGeofencingClient(context)
    }

    /**
     * 마지막으로 등록한 place id 집합.
     *
     * 프로세스가 죽으면 비지만, 앱이 뜰 때 `GeofenceRegistrationSync` 가
     * 다시 동기화하므로 실제 등록과 어긋난 채로 남지 않는다.
     */
    private var registered: Set<String> = emptySet()

    fun registeredIds(): List<String> = registered.toList()

    /**
     * 등록 상태를 [fences] 와 일치시킨다.
     *
     * 전부 지우고 다시 넣는다 — 지오펜스는 같은 id 로 덮어쓰기가 되고,
     * 개수가 최대 40개(장소 20 × 2)라 부분 갱신의 복잡도가 이득보다 크다.
     */
    @SuppressLint("MissingPermission")
    fun sync(fences: List<Map<String, Any?>>) {
        client.removeGeofences(pendingIntent())
        registered = emptySet()
        if (fences.isEmpty()) return

        val geofences = mutableListOf<Geofence>()
        val ids = mutableSetOf<String>()

        for (fence in fences) {
            val placeId = fence["placeId"] as? String ?: continue
            val lat = (fence["latitude"] as? Number)?.toDouble() ?: continue
            val lng = (fence["longitude"] as? Number)?.toDouble() ?: continue
            val radius = (fence["radiusMeters"] as? Number)?.toFloat() ?: continue
            val proximity = (fence["proximityRadiusMeters"] as? Number)?.toFloat() ?: continue

            geofences += buildGeofence(placeId, lat, lng, radius)
            geofences += buildGeofence(placeId + PROXIMITY_SUFFIX, lat, lng, proximity)
            ids += placeId
        }

        if (geofences.isEmpty()) return

        val request = GeofencingRequest.Builder()
            // 등록 시점에 이미 안이면 즉시 ENTER 를 받는다. unknown→inside 는
            // 무알림이므로(도메인 규칙 3) 가짜 알림이 되지 않고, 이게 없으면
            // 등록 직후의 첫 이탈을 통째로 놓친다.
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()

        try {
            client.addGeofences(request, pendingIntent())
                .addOnFailureListener { error ->
                    // **등록은 비동기다.** 여기서 실패하면 지오펜스가 하나도
                    // 걸리지 않은 채로 조용히 넘어간다 — 도착을 영영 감지하지
                    // 못하는데 예전에는 그 사실조차 알 수 없었다 (이슈 #95)
                    registered = emptySet()
                    DiagnosticLog.write(context, "registrar", "지오펜스 등록 실패 $error")
                }
                .addOnSuccessListener {
                    DiagnosticLog.write(
                        context,
                        "registrar",
                        "지오펜스 등록 성공 ${geofences.size}개 (장소 ${ids.size}곳)",
                    )
                }
            registered = ids
        } catch (error: SecurityException) {
            // 배경 위치 권한이 없다 — 온보딩이 받아야 한다.
            // 권한을 받은 뒤 다음 장소 목록 변경에서 재시도된다.
            DiagnosticLog.write(context, "registrar", "위치 권한 없음 — 등록 불가 $error")
        }
    }

    private fun buildGeofence(
        id: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Float,
    ): Geofence = Geofence.Builder()
        .setRequestId(id)
        .setCircularRegion(latitude, longitude, radiusMeters)
        .setExpirationDuration(Geofence.NEVER_EXPIRE)
        .setTransitionTypes(
            Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT,
        )
        // 기본 응답성(0) — 빠른 감지가 이 앱의 요구사항이다
        .setNotificationResponsiveness(0)
        .build()

    private fun pendingIntent(): PendingIntent {
        val intent = Intent(context, GeofenceReceiver::class.java)
            .setAction(GeofenceReceiver.ACTION_GEOFENCE_EVENT)
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }
}
