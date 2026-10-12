package kr.suhsaechan.ear_loc_alert

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.os.Looper
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * 중간 단계 위치 스트림 (이슈 #260)
 *
 * **왜 필요한가** — OS 지오펜스는 전달이 몇 분씩, 몇 km 씩 늦을 수 있다.
 * 근접 원 이벤트가 늦으면 앱은 그 사이 위치를 전혀 보지 못한 채 목적지를
 * 지나친다. 바깥 원 안에 있는 동안은 **균형 전력**(Wi-Fi·기지국 기반,
 * GPS 를 켜지 않는다)으로 앱이 직접 위치를 확인해 그 공백을 메운다.
 *
 * 주기와 거리 필터는 미검증 값이다 — 진단 기록의 `[mid]` 줄로 실측한다.
 */
class CoarseLocationTracker(private val context: Context) {

    companion object {
        /** 시속 60km 에서 1km 를 넘지 않는 간격 */
        private const val INTERVAL_MS = 60_000L
        private const val MIN_INTERVAL_MS = 30_000L

        /** 정지해 있으면 갱신 자체가 오지 않게 한다 — 배터리 보호의 핵심 */
        private const val MIN_DISPLACEMENT_M = 100f
    }

    private val client: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private var callback: LocationCallback? = null

    val isRunning: Boolean get() = callback != null

    /** 시작에 실패하면(권한 없음) false. 호출부가 사유를 기록한다 */
    @SuppressLint("MissingPermission")
    fun start(onLocation: (Location) -> Unit): Boolean {
        if (callback != null) return true

        val request = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, INTERVAL_MS)
            .setMinUpdateIntervalMillis(MIN_INTERVAL_MS)
            .setMinUpdateDistanceMeters(MIN_DISPLACEMENT_M)
            .build()

        val cb = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let(onLocation)
            }
        }

        return try {
            client.requestLocationUpdates(request, cb, Looper.getMainLooper())
            callback = cb
            true
        } catch (error: SecurityException) {
            false
        }
    }

    fun stop() {
        callback?.let { client.removeLocationUpdates(it) }
        callback = null
    }
}
