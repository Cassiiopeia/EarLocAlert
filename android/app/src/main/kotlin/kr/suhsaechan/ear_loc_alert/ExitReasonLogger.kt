package kr.suhsaechan.ear_loc_alert

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 직전 프로세스 종료 사유 기록 (이슈 #159, #134)
 *
 * **왜 남기나** — 감시가 조용히 끊겼을 때 프로세스가 언제, 왜 죽었는지 남은
 * 기록이 없어 원인을 가릴 수 없었다. OS 가 보관하는 종료 이력을 읽어 진단
 * 기록에 옮긴다. 이미 남긴 것은 다시 남기지 않는다(시각 기준).
 */
object ExitReasonLogger {

    fun logNew(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return
            val lastLogged = WatchState.exitLoggedAt(context)
            val exits = manager.getHistoricalProcessExitReasons(context.packageName, 0, 8)
                .filter { it.timestamp > lastLogged }
                .sortedBy { it.timestamp }
            for (exit in exits) {
                DiagnosticLog.write(
                    context,
                    "exit",
                    "프로세스 종료 이력 사유=${reasonName(exit.reason)} " +
                        "시각=${formatTime(exit.timestamp)} 중요도=${exit.importance} " +
                        "설명=${exit.description ?: "-"}",
                )
            }
            exits.lastOrNull()?.let { WatchState.markExitLogged(context, it.timestamp) }
        } catch (error: Exception) {
            DiagnosticLog.write(context, "exit", "종료 이력 조회 실패 $error")
        }
    }

    /** 진단 기록은 UTC ISO 표기다. 에폭 값만 남기면 사람이 읽을 수 없다 */
    private fun formatTime(millis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(millis))
    }

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "앱스스로종료"
        ApplicationExitInfo.REASON_SIGNALED -> "시그널"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "메모리부족"
        ApplicationExitInfo.REASON_CRASH -> "크래시"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "네이티브크래시"
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "초기화실패"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "권한변경"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "자원과다사용"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "사용자강제종료"
        ApplicationExitInfo.REASON_USER_STOPPED -> "사용자중지"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "의존성종료"
        ApplicationExitInfo.REASON_OTHER -> "기타"
        // API 34 에서 추가된 사유라 상수 대신 값으로 적는다. **앱 업데이트로 죽은
        // 것은 여기서 가려진다** — 이번 이슈가 알고 싶던 바로 그 구분이다
        14 -> "냉동(freezer)"
        15 -> "패키지상태변경"
        16 -> "앱업데이트로종료"
        else -> "알수없음($reason)"
    }
}
