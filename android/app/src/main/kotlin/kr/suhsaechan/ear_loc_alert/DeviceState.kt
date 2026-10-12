package kr.suhsaechan.ear_loc_alert

import android.content.Context
import android.os.BatteryManager
import android.os.PowerManager

/**
 * 진단 로그에 붙일 기기 상태 한 줄 (이슈 #260)
 *
 * 도착 알림이 늦었을 때 "화면이 꺼져 있었나, Doze 였나, 절전 모드였나"를
 * 사후에 가릴 수 있어야 한다. 값을 못 읽으면 `unknown` 으로 남긴다 —
 * 로그 때문에 예외가 나면 안 된다.
 */
object DeviceState {

    fun snapshot(context: Context): String {
        return try {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val battery = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            "screen=${if (power.isInteractive) "on" else "off"} " +
                "doze=${power.isDeviceIdleMode} " +
                "power_save=${power.isPowerSaveMode} " +
                "battery=$level%" +
                " charging=${battery.isCharging}"
        } catch (error: Exception) {
            "device_state=unknown($error)"
        }
    }
}
