package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock

/**
 * 재부팅·앱 교체 후 감시 복구 (이슈 #93, #159)
 *
 * **재부팅** — 매니페스트에 RECEIVE_BOOT_COMPLETED 권한과 "재부팅 후 감시 복구"
 * 주석은 있었으나 정작 이 리시버가 없어 재부팅 후 앱을 켜지 않으면 감시가
 * 죽은 채로 남았다.
 *
 * **앱 교체(#159)** — 스토어 자동 업데이트로 앱이 교체되면 프로세스가 죽고
 * 알람과 지오펜스 등록이 사라질 수 있다. 서비스의 START_STICKY 재시작에만
 * 기대지 않고, 교체 직후에도 부팅과 같은 경로로 복구한다.
 *
 * 두 갈래로 복구한다. 서비스를 띄워 엔진이 저장소에서 등록을 복원하게 하고,
 * 그와 별개로 네이티브 사본으로 즉시 다시 등록한다. 서비스 시작이 막혀도
 * 등록만큼은 살아남게 하기 위해서다.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reason = when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> "재부팅"
            Intent.ACTION_MY_PACKAGE_REPLACED -> "앱교체"
            else -> return
        }
        // 가동 시간을 함께 남긴다 — 일부 기기는 앱을 강제 종료했다 다시 실행할 때도
        // 부팅 완료 브로드캐스트를 다시 전달해, 사유만 보면 재부팅한 것으로 오해한다 (이슈 #161)
        val uptimeMinutes = SystemClock.elapsedRealtime() / 60_000L
        DiagnosticLog.write(context, "boot", "복구 시작 사유=$reason (기기 가동 ${uptimeMinutes}분)")

        ExitReasonLogger.logNew(context)
        WatchdogReceiver.restoreFromCache(context, reason)
        WatchdogReceiver.schedule(context)

        try {
            context.startForegroundService(
                Intent(context, AlertWatchService::class.java)
                    .setAction(AlertWatchService.ACTION_START_WATCH)
                    .putExtra(AlertWatchService.EXTRA_START_REASON, reason),
            )
        } catch (error: Exception) {
            // 삼키되 기록은 남긴다 — 예전에는 여기서 조용히 끝나 원인을 알 수 없었다.
            // 앱을 켜면 복구된다
            DiagnosticLog.write(context, "boot", "서비스 시작 실패 사유=$reason $error")
        }
    }
}
