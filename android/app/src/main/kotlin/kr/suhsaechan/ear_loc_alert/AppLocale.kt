package kr.suhsaechan.ear_loc_alert

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * 앱에서 고른 언어를 네이티브 문자열에 적용한다 (이슈 #164)
 *
 * **왜 필요한가** — 알림은 앱이 죽어 있어도 Kotlin 이 만든다. 그래서 Flutter 의
 * 번역을 쓸 수 없고, 사용자가 설정에서 기기와 다른 언어를 골랐다면 그 언어를
 * 네이티브가 직접 알아야 한다.
 *
 * **키 이름은 앱과 네이티브의 계약이다.** Dart 의 `AppLanguageStore.key`
 * (`app_language`)를 shared_preferences 플러그인이 `flutter.` 를 붙여
 * `FlutterSharedPreferences` 에 저장한다. 어느 한쪽 이름을 바꾸면 알림이
 * 앱과 다른 언어로 나온다.
 *
 * `system` 이거나 값이 없으면 손대지 않는다 — 기기 언어로 리소스가 고르고,
 * 지원하지 않는 기기 언어는 기본(영어)으로 떨어진다.
 */
object AppLocale {
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.app_language"

    /** 저장된 앱 언어를 적용한 컨텍스트. 문구는 여기서 `getString` 으로 읽는다 */
    fun localized(context: Context): Context {
        val stored = try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null)
        } catch (error: Exception) {
            // 읽지 못해도 알림은 나가야 한다 — 기기 언어로 떨어진다
            null
        }

        // 중국어는 간체만 지원한다(`values-zh-rCN`). 앱에서 zh 를 골랐다면 간체다
        val tag = when (stored) {
            "ko" -> "ko"
            "en" -> "en"
            "ja" -> "ja"
            "zh" -> "zh-CN"
            else -> return context
        }
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale.forLanguageTag(tag))
        return context.createConfigurationContext(config)
    }
}
