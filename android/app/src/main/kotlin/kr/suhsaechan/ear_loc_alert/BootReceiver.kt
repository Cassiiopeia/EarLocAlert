package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 재부팅 후 감시 복구 (이슈 #93)
 *
 * 매니페스트에 RECEIVE_BOOT_COMPLETED 권한과 "재부팅 후 감시 복구"
 * 주석은 있었으나 **정작 이 리시버가 없었다.** 그 결과 재부팅 후 앱을
 * 켜지 않으면 감시 서비스가 죽은 채로 남았다.
 *
 * OS 는 재부팅 후 지오펜스 등록을 복원하지 않는다. 서비스가 떠서 엔진을
 * 띄우고, 앱이 다음에 실행될 때 등록을 다시 밀어넣는다. 서비스만 살아
 * 있어도 이전에 저장된 대기 알림은 이어서 울린다.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            context.startForegroundService(
                Intent(context, AlertWatchService::class.java)
                    .setAction(AlertWatchService.ACTION_START_WATCH),
            )
        } catch (error: Exception) {
            // 부팅 직후 서비스 시작이 막혔다 — 앱을 켜면 복구된다
        }
    }
}
