package kr.suhsaechan.ear_loc_alert

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/**
 * APK 설치 화면 호출 (이슈 #104)
 *
 * **설치를 대신 하지 않는다.** 앱이 하는 것은 내려받은 APK 를 OS 설치
 * 화면에 넘기는 것까지다. 실제 설치는 사용자가 그 화면에서 확인한다 —
 * 대신 눌러줄 수 있는 API 도 없고, 있어도 그렇게 하면 안 된다.
 *
 * **왜 캐시 디렉토리인가** — 외부 저장소 권한 없이 쓸 수 있고, 설치가
 * 끝나면 OS 가 알아서 정리한다. 업데이트 파일이 기기에 영구히 쌓일 이유가
 * 없다.
 *
 * 스토어 배포가 시작되면 이 경로는 걷어낸다 (docs/11-ROADMAP.md).
 */
class ApkInstaller(private val context: Context) {

    companion object {
        /** `AndroidManifest.xml` 의 provider authorities 와 계약이다 */
        private const val AUTHORITY_SUFFIX = ".fileprovider"

        /** `file_paths.xml` 의 cache-path 와 계약이다 */
        private const val DIR_NAME = "update"
    }

    /**
     * APK 를 캐시에 쓰고 설치 화면을 띄운다.
     *
     * 실패하면 예외를 던진다 — 업데이트는 사용자가 방금 직접 누른 행동이라
     * 조용히 실패하면 안 된다. 아무 일도 안 일어나는 화면이 가장 나쁘다.
     */
    fun install(bytes: ByteArray, fileName: String) {
        val dir = File(context.cacheDir, DIR_NAME).apply { mkdirs() }

        // 이전 내려받기가 남아 있으면 지운다 — 버전이 섞이면 엉뚱한 것이 깔린다
        dir.listFiles()?.forEach { it.delete() }

        val file = File(dir, fileName)
        file.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(
            context,
            context.packageName + AUTHORITY_SUFFIX,
            file,
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            // 서비스·비액티비티 컨텍스트에서도 뜨게 한다
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // FileProvider URI 는 이 플래그 없이는 설치 프로그램이 읽지 못한다
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
    }

    /**
     * "출처를 알 수 없는 앱 설치"가 허용되어 있는가 (Android 8+).
     *
     * 허용 전에는 설치 화면이 곧바로 설정으로 튕긴다. 미리 확인해서
     * 사용자에게 무엇을 켜야 하는지 알려주는 편이 낫다.
     */
    fun canInstall(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return context.packageManager.canRequestPackageInstalls()
    }

    /** 설치 권한 설정 화면을 연다 */
    fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (error: Exception) {
            // 기기가 이 화면을 갖고 있지 않다 — 설치 시도에서 OS 가 안내한다
        }
    }
}
