package kr.suhsaechan.ear_loc_alert

import android.annotation.SuppressLint
import android.content.Context
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * 현재 위치 1회 조회 (이슈 #98)
 *
 * **왜 필요한가** — 지도의 "내 위치" 버튼을 직접 만들려면 좌표를 알아야
 * 한다. 예전에는 그 수단이 없어 지도 SDK 기본 버튼을 썼는데, 그 버튼은
 * 우상단 고정이라 상태 알약에 가려 잘려 보였고 사용자가 존재를 몰랐다.
 *
 * 이슈 #93 에서 `play-services-location` 을 이미 넣었으므로 새 의존성 없이
 * 조회만 노출하면 된다.
 *
 * 스트림이 아니라 **1회 조회**다 — 버튼을 누른 그 순간만 필요하고,
 * 스트림을 열면 화면을 보는 내내 배터리를 먹는다.
 */
class CurrentLocationProvider(private val context: Context) {

    /**
     * 현재 위치를 구해 [onResult] 로 넘긴다. 실패하면 null.
     *
     * `getCurrentLocation` 을 쓰는 이유는 `lastLocation` 이 **오래된 값이나
     * null 을 주기 때문**이다. 버튼을 눌렀는데 어제 있던 곳으로 지도가
     * 날아가면 고장으로 보인다.
     */
    @SuppressLint("MissingPermission")
    fun fetch(onResult: (Pair<Double, Double>?) -> Unit) {
        val client = LocationServices.getFusedLocationProviderClient(context)
        val request = CurrentLocationRequest.Builder()
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            // 버튼을 누르고 기다리는 시간이다 — 길면 눌렀는지 의심하게 된다
            .setDurationMillis(10_000)
            .setMaxUpdateAgeMillis(30_000)
            .build()

        try {
            client.getCurrentLocation(request, null)
                .addOnSuccessListener { location ->
                    if (location == null) {
                        DiagnosticLog.write(context, "location", "현재 위치 조회 결과 없음")
                        onResult(null)
                    } else {
                        onResult(location.latitude to location.longitude)
                    }
                }
                .addOnFailureListener { error ->
                    DiagnosticLog.write(context, "location", "현재 위치 조회 실패 $error")
                    onResult(null)
                }
        } catch (error: SecurityException) {
            // 위치 권한이 없다 — 화면이 이유를 안내한다
            DiagnosticLog.write(context, "location", "위치 권한 없음 — 조회 불가")
            onResult(null)
        }
    }
}
