package kr.suhsaechan.ear_loc_alert

import android.Manifest
import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationManagerCompat
import java.util.Locale
import java.util.TimeZone

/**
 * 기기와 앱의 기본 정보 한 줄 (이슈 #260)
 *
 * **왜 필요한가** — 백그라운드 도착 알림은 제조사 절전 정책, 앱 대기 버킷,
 * 배터리 최적화에 크게 좌우된다. 같은 코드가 어떤 기기에서는 되고 어떤
 * 기기에서는 늦는데, 로그에 기기 정보가 없으면 그 차이를 설명할 수 없다.
 *
 * **개인을 특정하는 값은 넣지 않는다** — 일련번호·광고 ID·ANDROID_ID 는
 * 읽지 않는다. 모델명과 OS 버전, 앱 상태만 담는다.
 *
 * 값을 못 읽으면 `?` 로 남기고 예외를 올리지 않는다 — 진단 때문에 앱이
 * 흔들리면 안 된다.
 */
object DeviceInfo {

    private fun <T> safe(block: () -> T): String =
        try {
            block().toString()
        } catch (error: Exception) {
            // 항목 하나만 "?" 로 표시한다 — 요약 줄 전체가 기록이라 별도 로그는 중복이다
            "?"
        }

    fun summary(context: Context): String {
        val pm = context.packageManager
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager

        val fields = linkedMapOf<String, String>()
        fields["maker"] = Build.MANUFACTURER
        fields["brand"] = Build.BRAND
        fields["model"] = Build.MODEL
        fields["device"] = Build.DEVICE
        fields["android"] = "${Build.VERSION.RELEASE}(sdk${Build.VERSION.SDK_INT})"
        fields["patch"] = safe { Build.VERSION.SECURITY_PATCH }
        fields["app"] = "${BuildConfig.VERSION_NAME}(${BuildConfig.VERSION_CODE})"
        fields["dev_build"] = BuildConfig.DEV_FLAG.toString()
        fields["installer"] = safe {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pm.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(context.packageName)
            }
        }
        fields["locale"] = Locale.getDefault().toLanguageTag()
        fields["tz"] = TimeZone.getDefault().id
        fields["play_services"] = safe {
            val info = pm.getPackageInfo("com.google.android.gms", 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
            else @Suppress("DEPRECATION") info.versionCode
        }
        fields["ram_mb"] = safe {
            val info = ActivityManager.MemoryInfo()
            activity?.getMemoryInfo(info)
            info.totalMem / (1024 * 1024)
        }
        fields["low_ram"] = safe { activity?.isLowRamDevice }

        // 아래 셋은 백그라운드 전달이 늦거나 끊기는 원인이 되는 OS 상태다
        fields["standby_bucket"] = safe {
            val usage = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            bucketName(usage.appStandbyBucket)
        }
        fields["bg_restricted"] = safe {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) activity?.isBackgroundRestricted else null
        }
        fields["ignoring_battery_opt"] = safe {
            power?.isIgnoringBatteryOptimizations(context.packageName)
        }

        fields["perm_fine"] = granted(context, Manifest.permission.ACCESS_FINE_LOCATION)
        fields["perm_coarse"] = granted(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        fields["perm_background"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            granted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else {
            "n/a"
        }
        fields["notifications"] = safe { NotificationManagerCompat.from(context).areNotificationsEnabled() }

        return fields.entries.joinToString(" ") { (key, value) -> "$key=$value" }
    }

    private fun granted(context: Context, permission: String): String =
        safe { context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED }

    /** 대기 버킷 값을 사람이 읽는 이름으로 — 숫자만 남기면 해석이 어렵다 */
    private fun bucketName(bucket: Int): String = when (bucket) {
        UsageStatsManager.STANDBY_BUCKET_ACTIVE -> "active"
        UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> "working_set"
        UsageStatsManager.STANDBY_BUCKET_FREQUENT -> "frequent"
        UsageStatsManager.STANDBY_BUCKET_RARE -> "rare"
        UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> "restricted"
        else -> "other($bucket)"
    }
}
