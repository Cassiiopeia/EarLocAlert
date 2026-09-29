package kr.suhsaechan.ear_loc_alert

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock

/**
 * 주기 점검 (이슈 #159)
 *
 * **왜 필요한가** — OS 에 등록된 지오펜스를 앱이 조회할 방법은 없다. 등록이
 * 조용히 사라지면(원인이 앱 교체든 절전이든 Play 서비스 정리든) 신호가 아예
 * 오지 않아 앱은 죽은 줄도 모른다. 그래서 **원인과 무관하게 주기적으로 다시
 * 등록**해 공백을 최대 [INTERVAL_MS] 로 묶는다.
 *
 * 엔진 없이 네이티브 사본([WatchState])으로 바로 복구한다 — 서비스가 죽어
 * 있어도 도는 경로여야 하기 때문이다. 등록은 같은 id 로 덮어쓰기라 여러 번
 * 해도 안전하고, 이미 안에 있을 때의 ENTER 는 Dart 의 상태 전이 규칙
 * (`inside → inside` 는 무알림)이 흡수한다.
 *
 * 알람은 재부팅·앱 교체·강제 종료로 사라지므로 그 뒤에는 [schedule] 을
 * 다시 불러야 한다 (`BootReceiver`, 서비스 생성).
 */
class WatchdogReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_WATCHDOG = "kr.suhsaechan.ear_loc_alert.WATCHDOG"

        /**
         * 점검 간격.
         *
         * 짧을수록 공백이 줄지만, 근접 반경 안에 머무는 동안 다시 등록할
         * 때마다 정밀 감시(최대 30분)가 켜진다. 6시간이면 그 비용이 하루
         * 4번 이하로 묶인다.
         */
        const val INTERVAL_MS = 6 * 60 * 60 * 1000L

        private const val REQUEST_CODE = 4001

        /** 다음 점검을 예약한다. 이미 있으면 덮어쓴다 */
        fun schedule(context: Context) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return
            // 정확한 시각이 필요 없다 — Doze 중에도 깨우되 OS 가 묶어 처리하게 둔다
            manager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + INTERVAL_MS,
                pendingIntent(context),
            )
        }

        private fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WatchdogReceiver::class.java)
                .setAction(ACTION_WATCHDOG)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * 저장된 사본으로 지오펜스를 복구한다.
         *
         * 부팅·앱 교체·주기 점검이 함께 쓴다. 저장된 것이 없으면(앱을 한 번도
         * 안 켰거나 장소가 없다) 할 일이 없다.
         */
        fun restoreFromCache(context: Context, reason: String) {
            val fences = WatchState.loadFences(context)
            if (fences.isEmpty()) {
                DiagnosticLog.write(context, "watchdog", "recovery skipped reason=$reason no stored geofences")
                return
            }
            GeofenceRegistrar(context).sync(fences)
            WatchState.markRegistered(context)
            DiagnosticLog.write(
                context,
                "watchdog",
                "geofence recovery requested reason=$reason places=${fences.size}",
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_WATCHDOG) return

        val now = System.currentTimeMillis()
        // 생존 기록 — 신호가 없을 때 조용한 것인지 죽은 것인지 가르는 근거다
        DiagnosticLog.write(
            context,
            "watchdog",
            "check service=${if (AlertWatchService.isRunning) "running" else "absent"} " +
                "last_registered=${WatchState.agoText(WatchState.registeredAt(context), now)} " +
                "last_received=${WatchState.agoText(WatchState.eventAt(context), now)}",
        )

        ExitReasonLogger.logNew(context)
        restoreFromCache(context, "watchdog")

        // 서비스가 없으면 되살린다. 백그라운드 시작 제한에 걸릴 수 있어 삼키되 기록한다
        if (!AlertWatchService.isRunning) {
            try {
                context.startForegroundService(
                    Intent(context, AlertWatchService::class.java)
                        .setAction(AlertWatchService.ACTION_START_WATCH)
                        .putExtra(AlertWatchService.EXTRA_START_REASON, "watchdog"),
                )
            } catch (error: Exception) {
                DiagnosticLog.write(context, "watchdog", "service start failed $error")
            }
        }

        // 다음 점검 예약 — 알람은 한 번만 울린다
        schedule(context)
    }
}
