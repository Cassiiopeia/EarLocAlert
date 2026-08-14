package kr.suhsaechan.ear_loc_alert

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 네이티브 진단 로그 (이슈 #95)
 *
 * **왜 파일에 직접 쓰나** — `android.util.Log` 는 logcat 으로 가는데,
 * Android 4.1+ 부터 앱은 자기 프로세스의 logcat 조차 읽을 수 없다.
 * 사용자 기기에서 "왜 안 울렸는지"를 확인하려면 앱이 읽을 수 있는 곳에
 * 남아야 한다.
 *
 * **Dart 와 같은 파일에 쌓는다.** `filesDir` 는 path_provider 의
 * `getApplicationSupportDirectory()` 와 같은 곳이라, 한 화면에서
 * 네이티브와 Dart 기록이 시간순으로 섞여 읽힌다. 지오펜스 이벤트가
 * 네이티브까지 왔는데 Dart 판정이 안 돌았는지, 아예 안 왔는지를
 * 가르는 것이 이 로그의 핵심 용도다.
 *
 * 파일명은 `DiagnosticLogFile.fileName` 과 계약이다 — 한쪽을 바꾸면
 * 반대쪽도 바꿔야 한다.
 *
 * **어떤 호출도 예외를 던지지 않는다.** 로깅이 감시를 죽이면 안 된다.
 */
object DiagnosticLog {

    private const val FILE_NAME = "diagnostic.log"

    /** Dart `FileDiagnosticLogger.defaultMaxBytes` 와 같은 값 */
    private const val MAX_BYTES = 5L * 1024 * 1024

    private val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        .apply { timeZone = TimeZone.getTimeZone("UTC") }

    /** 여러 스레드에서 동시에 부른다 — 줄이 섞이면 읽을 수 없다 */
    private val lock = Any()

    fun write(context: Context, tag: String, message: String) {
        synchronized(lock) {
            try {
                val file = File(context.filesDir, FILE_NAME)
                val flat = message.replace('\n', ' ').replace('\r', ' ')
                val line = "${formatter.format(Date())} [$tag] $flat\n"
                file.appendText(line)
                rotateIfNeeded(file)
            } catch (error: Exception) {
                // 로그를 못 남기는 것은 불편이지 고장이 아니다
            }
        }
    }

    /**
     * 상한을 넘으면 오래된 쪽을 버린다.
     *
     * Dart `trimToLimit` 과 같은 규칙이다 — 최근 것을 남긴다.
     * 문제는 언제나 방금 일어나기 때문이다.
     */
    private fun rotateIfNeeded(file: File) {
        if (file.length() <= MAX_BYTES) return
        try {
            val lines = file.readLines()
            var bytes = 0L
            val kept = ArrayDeque<String>()
            for (line in lines.asReversed()) {
                val size = line.toByteArray().size + 1
                if (bytes + size > MAX_BYTES) break
                kept.addFirst(line)
                bytes += size
            }
            file.writeText(kept.joinToString("\n", postfix = "\n"))
        } catch (error: Exception) {
            // 회전 실패는 파일이 조금 커지는 문제일 뿐이다
        }
    }
}
