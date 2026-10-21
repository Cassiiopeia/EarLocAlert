package kr.suhsaechan.ear_loc_alert

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.location.LocationManager
import android.os.Build
import android.provider.Settings

/**
 * 진단 보고서용 네이티브 상태 전체 (이슈 #290)
 * 구역 7개: 기기, 기기 상태, 위치 서비스, 특수 권한, 알림 채널, 감시 서비스, 프로세스 종료 이력
 *
 * 값을 못 읽은 항목은 `?(사유)` 로 남기고 나머지는 계속 읽는다 — 보고서 하나 때문에
 * 앱이 흔들리면 안 된다. 기기를 특정하는 값(일련번호·광고 ID·ANDROID_ID)은 읽지 않는다.
 */
object DebugSnapshot {

    // 종료 이력 조회 건수 (OS 보관 상한보다 작게)
    private const val EXIT_HISTORY_LIMIT = 16

    fun collect(context: Context): String {
        val lines = mutableListOf<String>()
        section(lines, "device") { listOf(DeviceInfo.summary(context)) }
        section(lines, "device_state") { listOf(DeviceState.snapshot(context)) }
        section(lines, "location_services") { locationServices(context) }
        section(lines, "special_access") { specialAccess(context) }
        section(lines, "notification_channels") { notificationChannels(context) }
        section(lines, "watch_service") { watchService(context) }
        section(lines, "process_exits") { processExits(context) }
        return lines.joinToString("\n")
    }

    /** 구역 머리 + 본문 (실패 시 사유 한 줄) */
    private fun section(lines: MutableList<String>, name: String, block: () -> List<String>) {
        lines += "[$name]"
        try {
            lines += block()
        } catch (error: Exception) {
            lines += "unavailable error=$error"
        }
    }

    private fun locationServices(context: Context): List<String> {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return listOf(
            "enabled=${safe { manager.isLocationEnabled }}",
            "gps=${safe { manager.isProviderEnabled(LocationManager.GPS_PROVIDER) }}",
            "network=${safe { manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) }}",
        )
    }

    /** 오버레이·전체화면 알림·정확한 알람 (화면 승격 경로의 전제) */
    private fun specialAccess(context: Context): List<String> {
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return listOf(
            "overlay=${safe { Settings.canDrawOverlays(context) }}",
            "full_screen_intent=" + if (Build.VERSION.SDK_INT >= 34) {
                safe { notifications.canUseFullScreenIntent() }
            } else {
                "n/a(sdk<34)"
            },
            "exact_alarm=" + if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                safe { alarms.canScheduleExactAlarms() }
            } else {
                "n/a(sdk<31)"
            },
            "notifications_enabled=${safe { notifications.areNotificationsEnabled() }}",
        )
    }

    /** 채널별 중요도·소리·진동 — 사용자가 채널만 꺼도 알림이 사라진다 */
    private fun notificationChannels(context: Context): List<String> {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = manager.notificationChannels
        if (channels.isEmpty()) return listOf("none")
        return channels.map { channel ->
            "id=${channel.id} importance=${channel.importance} " +
                "sound=${channel.sound != null} vibration=${channel.shouldVibrate()} " +
                "lockscreen=${channel.lockscreenVisibility} bypass_dnd=${channel.canBypassDnd()}"
        }
    }

    /** 서비스 생존·마지막 등록·마지막 이벤트·저장된 감시 대상 */
    private fun watchService(context: Context): List<String> {
        val now = System.currentTimeMillis()
        val registeredAt = WatchState.registeredAt(context)
        val eventAt = WatchState.eventAt(context)
        val fences = WatchState.loadFences(context)
        val lines = mutableListOf(
            "running=${AlertWatchService.isRunning} alerting=${AlertWatchService.alertingNow}",
            "registered_place_ids=${AlertWatchService.registeredPlaceIds().joinToString(",").ifEmpty { "-" }}",
            "last_registered=${isoOrNever(registeredAt)} (${WatchState.agoText(registeredAt, now)})",
            "last_event=${isoOrNever(eventAt)} (${WatchState.agoText(eventAt, now)})",
            "saved_fences=${fences.size}",
        )
        // 저장된 감시 대상 원본 (엔진 복원 경로가 읽는 값)
        fences.forEach { fence ->
            lines += "  fence " + fence.entries.sortedBy { it.key }
                .joinToString(" ") { (key, value) -> "$key=$value" }
        }
        return lines
    }

    /** OS 보관 종료 이력 전체 (이미 로그에 옮긴 것 포함) */
    private fun processExits(context: Context): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return listOf("n/a(sdk<30)")
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val exits = manager.getHistoricalProcessExitReasons(context.packageName, 0, EXIT_HISTORY_LIMIT)
        if (exits.isEmpty()) return listOf("none")
        return exits.map { exit ->
            "time=${ExitReasonLogger.formatTime(exit.timestamp)} " +
                "reason=${ExitReasonLogger.reasonName(exit.reason)} " +
                "importance=${exit.importance} pss_kb=${exit.pss} rss_kb=${exit.rss} " +
                "description=${exit.description ?: "-"}"
        }
    }

    private fun isoOrNever(millis: Long): String =
        if (millis <= 0L) "never" else ExitReasonLogger.formatTime(millis)

    private fun <T> safe(block: () -> T): String =
        try {
            block().toString()
        } catch (error: Exception) {
            "?($error)"
        }
}
