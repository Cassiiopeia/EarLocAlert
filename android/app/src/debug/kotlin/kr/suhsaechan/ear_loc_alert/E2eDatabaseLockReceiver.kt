package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import java.io.File

/**
 * e2e 전용 DB 쓰기 잠금 주입: 앱 DB 에 쓰기 트랜잭션을 N초 잡았다가 놓음 (#345)
 * 디버그 소스셋에만 있음 > 릴리스 APK 에는 수신기 자체가 없다
 *
 * 호출: am broadcast -n kr.suhsaechan.ear_loc_alert/.E2eDatabaseLockReceiver --ei seconds 8
 */
class E2eDatabaseLockReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val holdSeconds = intent.getIntExtra(EXTRA_SECONDS, DEFAULT_HOLD_SECONDS)
            .coerceIn(1, MAX_HOLD_SECONDS)
        val appContext = context.applicationContext
        // 수신기는 바로 반환 (메인 스레드를 막으면 ANR) > 잠금은 별도 스레드가 잡는다
        Thread { holdWriteLock(appContext, holdSeconds) }.start()
    }

    /** 쓰기 잠금 유지: 열기 > BEGIN IMMEDIATE > 대기 > 롤백 (성공·실패 모두 기록) */
    private fun holdWriteLock(context: Context, holdSeconds: Int) {
        // Dart getApplicationDocumentsDirectory() = {dataDir}/app_flutter
        val databaseFile = File(context.dataDir, DATABASE_RELATIVE_PATH)
        if (!databaseFile.exists()) {
            DiagnosticLog.write(context, TAG, "db lock skipped reason=no_database path=$DATABASE_RELATIVE_PATH")
            return
        }
        var database: SQLiteDatabase? = null
        try {
            // WAL 유지 필수: 기본 열기는 저널 모드를 바꿔 앱 연결(WAL)과 섞이며 파일이 깨진다
            // 지역화 콜레이터 끔: android_metadata 테이블을 만들지 않게
            val openFlags = SQLiteDatabase.OPEN_READWRITE or
                SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING or
                SQLiteDatabase.NO_LOCALIZED_COLLATORS
            database = SQLiteDatabase.openDatabase(databaseFile.path, null, openFlags)
            val journalMode = database.rawQuery("PRAGMA journal_mode", null).use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
            if (!journalMode.equals(REQUIRED_JOURNAL_MODE, ignoreCase = true)) {
                DiagnosticLog.write(context, TAG, "db lock skipped reason=journal_mode_mismatch mode=$journalMode")
                return
            }
            database.beginTransactionNonExclusive()
            DiagnosticLog.write(context, TAG, "db lock held seconds=$holdSeconds")
            Thread.sleep(holdSeconds * 1000L)
            database.endTransaction()
            DiagnosticLog.write(context, TAG, "db lock released seconds=$holdSeconds")
        } catch (error: Exception) {
            DiagnosticLog.write(context, TAG, "db lock failed error=${error.javaClass.simpleName}: ${error.message}")
        } finally {
            database?.close()
        }
    }

    private companion object {
        const val TAG = "e2e"
        const val EXTRA_SECONDS = "seconds"
        const val DEFAULT_HOLD_SECONDS = 8

        // 잠금 상한 (60초): 실수로 큰 값을 줘도 앱이 계속 막히지 않게
        const val MAX_HOLD_SECONDS = 60
        const val DATABASE_RELATIVE_PATH = "app_flutter/ear_loc_alert.sqlite"

        // 앱 DB 저널 모드 (app_database.dart configureDatabaseConnection 과 같아야 함)
        const val REQUIRED_JOURNAL_MODE = "wal"
    }
}
