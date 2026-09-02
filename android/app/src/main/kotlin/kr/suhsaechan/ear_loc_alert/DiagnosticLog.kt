package kr.suhsaechan.ear_loc_alert

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.zip.GZIPOutputStream

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

    /**
     * 압축 보관본 — Dart `DiagnosticLogFile.archiveFileName` 과 계약이다.
     *
     * **앱이 떠 있지 않을 때도 회전이 일어난다.** 감시 서비스는 앱과
     * 무관하게 돌므로, 여기서 버리면 Dart 가 보관할 기회가 없다.
     */
    private const val ARCHIVE_NAME = "diagnostic.1.log.gz"

    /** Dart `FileDiagnosticLogger.defaultMaxBytes` 와 같은 값 */
    private const val MAX_BYTES = 2L * 1024 * 1024

    /**
     * 회전 후 남길 비율 — Dart `_keepRatioAfterRotate` 와 같은 값 (이슈 #110).
     *
     * **상한까지만 자르면 다음 한 줄에 또 넘는다.** 그러면 기록할 때마다
     * 파일 전체를 읽고 쓰게 되어, 로그 한 줄이 수 메가바이트 I/O 가 된다.
     * 감시 서비스에서 이건 그냥 고장이다.
     */
    private const val KEEP_AFTER_ROTATE = 0.7

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
     * 상한을 넘으면 **압축해 보관하고** 현재 파일을 비운다 (이슈 #127).
     *
     * 예전에는 오래된 쪽을 그냥 버렸다. 실기기에서 정밀 감시가 도는 날은
     * 하루 만에 상한이 차서 전날 기록을 볼 수 없었다. 텍스트라 gzip 이
     * 대략 10:1 로 줄인다 — 회전은 드물게 일어나므로 압축 비용도 드물다.
     *
     * Dart `LogArchive.rotate` 와 같은 규칙이다. 어느 쪽이 회전하든
     * 결과가 같아야 한다.
     */
    private fun rotateIfNeeded(file: File) {
        if (file.length() <= MAX_BYTES) return
        if (archiveInto(file)) return
        // 압축이 실패하면 예전 방식(잘라내기)으로 떨어진다 —
        // 여기서 포기하면 파일이 상한을 넘은 채 영영 자란다
        try {
            // **깨진 바이트에 견뎌야 한다** (이슈 #106).
            //
            // 이 파일은 Dart(앱 isolate·감시 엔진)와 여기가 함께 append
            // 한다. 쓰기가 겹치면 한글 한 글자(UTF-8 3바이트)가 중간에서
            // 잘릴 수 있는데, 기본 디코딩은 그 순간 예외를 던진다.
            // 그러면 회전이 영영 실패해 파일이 상한을 넘은 채 자란다.
            //
            // Kotlin 의 `String(bytes, UTF_8)` 은 깨진 바이트를 대체
            // 문자로 바꾼다 — 그 줄만 이상해 보이고 나머지는 살아남는다.
            val lines = String(file.readBytes(), Charsets.UTF_8).lines()
            val target = (MAX_BYTES * KEEP_AFTER_ROTATE).toLong()
            var bytes = 0L
            val kept = ArrayDeque<String>()
            for (line in lines.asReversed()) {
                val size = line.toByteArray().size + 1
                if (bytes + size > target) break
                kept.addFirst(line)
                bytes += size
            }
            file.writeText(kept.joinToString("\n", postfix = "\n"))
        } catch (error: Exception) {
            // 회전 실패는 파일이 조금 커지는 문제일 뿐이다
        }
    }

    /**
     * 현재 로그를 gzip 으로 보관하고 원본을 비운다.
     *
     * 직전 세대를 덮어쓴다 — 이 로그의 목적은 며칠 안의 추적이라
     * 두 세대면 충분하다.
     *
     * @return 보관에 성공했으면 true
     */
    private fun archiveInto(file: File): Boolean {
        return try {
            val bytes = file.readBytes()
            if (bytes.isEmpty()) return true

            val archive = File(file.parentFile, ARCHIVE_NAME)
            GZIPOutputStream(archive.outputStream()).use { it.write(bytes) }
            file.writeText("")
            true
        } catch (error: Exception) {
            false
        }
    }
}
