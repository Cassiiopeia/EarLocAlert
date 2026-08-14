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
 * 정밀 모드 위치 스트림 (이슈 #93)
 *
 * 근접 반경 안에 있는 동안만 돈다. OS 지오펜스는 감지가 수십 초 늦을 수
 * 있어 "셔틀버스에서 내릴 곳"에는 부족하다. 근처에 왔을 때만 직접 보고
 * 몇 초 안에 판정한다.
 *
 * **주기는 미검증 값이다** — 실기기 배터리 실측 후 확정한다.
 */
class PreciseLocationTracker(private val context: Context) {

    companion object {
        /** 시속 60km(≈17m/s)에서 반경 100m 를 놓치지 않는 간격 */
        private const val INTERVAL_MS = 5_000L
        private const val MIN_INTERVAL_MS = 3_000L

        /** 정지 상태에서 불필요한 갱신을 막는다 */
        private const val MIN_DISPLACEMENT_M = 10f
    }

    private val client: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private var callback: LocationCallback? = null

    val isRunning: Boolean get() = callback != null

    @SuppressLint("MissingPermission")
    fun start(onLocation: (Location) -> Unit) {
        if (callback != null) return

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, INTERVAL_MS)
            .setMinUpdateIntervalMillis(MIN_INTERVAL_MS)
            .setMinUpdateDistanceMeters(MIN_DISPLACEMENT_M)
            .build()

        val cb = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let(onLocation)
            }
        }

        try {
            client.requestLocationUpdates(request, cb, Looper.getMainLooper())
            callback = cb
        } catch (error: SecurityException) {
            // 위치 권한이 없다 — 실제 반경 지오펜스 폴백으로 성립한다.
            // 알림이 수십 초 늦을 뿐 사라지지는 않는다.
        }
    }

    fun stop() {
        callback?.let { client.removeLocationUpdates(it) }
        callback = null
    }
}
