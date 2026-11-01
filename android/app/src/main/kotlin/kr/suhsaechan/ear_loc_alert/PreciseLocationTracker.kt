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
 * 주기는 경계까지 거리로 정한다 (#318, [PreciseWatchPolicy.intervalFor]) — 경계 근처 5초, 멀면 최대 40초
 */
class PreciseLocationTracker(private val context: Context) {

    companion object {
        /** 요청 주기 대비 허용 최소 간격 비율 (5초 요청 > 3초, #93 의 원래 비율) */
        private const val MIN_INTERVAL_RATIO = 0.6

        /** 정지 상태에서 불필요한 갱신을 막는다 */
        private const val MIN_DISPLACEMENT_M = 10f
    }

    private val client: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private var callback: LocationCallback? = null

    /** 지금 요청 중인 주기(ms). 멈춰 있으면 0 */
    var intervalMilliseconds: Long = 0L
        private set

    val isRunning: Boolean get() = callback != null

    @SuppressLint("MissingPermission")
    fun start(intervalMs: Long, onLocation: (Location) -> Unit) {
        if (callback != null) return

        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let(onLocation)
            }
        }

        try {
            client.requestLocationUpdates(buildRequest(intervalMs), locationCallback, Looper.getMainLooper())
            callback = locationCallback
            intervalMilliseconds = intervalMs
        } catch (error: SecurityException) {
            // 위치 권한이 없다 — 실제 반경 지오펜스 폴백으로 성립한다.
            // 알림이 수십 초 늦을 뿐 사라지지는 않는다.
            DiagnosticLog.write(context, "precise", "location permission missing, tracking unavailable $error")
        }
    }

    /** 주기 변경: 같은 콜백으로 다시 요청 (FLP 는 같은 콜백 재요청 시 기존 요청을 대체) */
    @SuppressLint("MissingPermission")
    fun updateInterval(intervalMs: Long): Boolean {
        val activeCallback = callback ?: return false
        if (intervalMs == intervalMilliseconds) return false
        return try {
            client.requestLocationUpdates(buildRequest(intervalMs), activeCallback, Looper.getMainLooper())
            intervalMilliseconds = intervalMs
            true
        } catch (error: SecurityException) {
            DiagnosticLog.write(context, "precise", "interval update failed reason=permission_missing $error")
            false
        }
    }

    fun stop() {
        callback?.let { client.removeLocationUpdates(it) }
        callback = null
        intervalMilliseconds = 0L
    }

    private fun buildRequest(intervalMs: Long): LocationRequest =
        LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateIntervalMillis((intervalMs * MIN_INTERVAL_RATIO).toLong())
            .setMinUpdateDistanceMeters(MIN_DISPLACEMENT_M)
            .build()
}
