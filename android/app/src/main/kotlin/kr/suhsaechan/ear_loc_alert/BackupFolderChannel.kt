package kr.suhsaechan.ear_loc_alert

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 자동 백업 폴더 (#314): 사용자가 고른 폴더(저장소 접근 프레임워크)에 백업 파일 덮어쓰기
 * 폴더 권한은 영구 권한으로 유지, 폴더 주소는 SharedPreferences 에 보관
 * 메서드 4개: pickFolder, folderName, write(fileName, content), clearFolder
 */
class BackupFolderChannel(private val activity: Activity) {
    companion object {
        const val CHANNEL = "kr.suhsaechan.ear_loc_alert/backup_folder"
        const val REQUEST_CODE_PICK_FOLDER = 31401

        // prefs: 고른 폴더 tree URI
        private const val PREFS_NAME = "auto_backup_native"
        private const val KEY_TREE_URI = "tree_uri"
        private const val JSON_MIME = "application/json"
    }

    /** 폴더 고르기 응답 대기 (한 번에 하나) */
    private var pendingPick: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFolder" -> pickFolder(result)
                "folderName" -> result.success(folderName())
                "write" -> {
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (fileName == null || content == null) {
                        result.error("bad_args", "fileName and content required", null)
                    } else {
                        result.success(write(fileName, content))
                    }
                }
                "clearFolder" -> {
                    clearFolder()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "folder picker already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            activity.startActivityForResult(intent, REQUEST_CODE_PICK_FOLDER)
        } catch (error: Exception) {
            pendingPick = null
            DiagnosticLog.write(activity, "backup", "folder picker open failed $error")
            result.success(null)
        }
    }

    /** MainActivity.onActivityResult 가 넘김. 처리했으면 true */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_FOLDER) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val treeUri = data?.data
        if (resultCode != Activity.RESULT_OK || treeUri == null) {
            DiagnosticLog.write(activity, "backup", "folder pick cancelled")
            result.success(null)
            return true
        }
        try {
            // 앱을 다시 켜도 쓰기 권한이 남게 영구 권한으로 (권한 없으면 다음 쓰기가 실패)
            activity.contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            releasePreviousFolder(treeUri)
            prefs().edit().putString(KEY_TREE_URI, treeUri.toString()).apply()
            val name = folderName()
            DiagnosticLog.write(activity, "backup", "folder picked name=$name")
            result.success(name)
        } catch (error: Exception) {
            DiagnosticLog.write(activity, "backup", "folder permission failed $error")
            result.success(null)
        }
        return true
    }

    /** 고른 폴더 이름. 없거나 권한을 잃었으면 null */
    private fun folderName(): String? {
        val treeUri = savedTreeUri() ?: return null
        if (!hasWritePermission(treeUri)) return null
        return queryDisplayName(directoryDocumentUri(treeUri)) ?: treeUri.lastPathSegment
    }

    /** 폴더 안 [fileName] 을 [content] 로 덮어씀 (없으면 만듦). 실패하면 false */
    private fun write(fileName: String, content: String): Boolean {
        val treeUri = savedTreeUri() ?: return false
        if (!hasWritePermission(treeUri)) {
            DiagnosticLog.write(activity, "backup", "write skipped reason=permission_lost")
            return false
        }
        return try {
            val fileUri = findChild(treeUri, fileName)
                ?: DocumentsContract.createDocument(
                    activity.contentResolver,
                    directoryDocumentUri(treeUri),
                    JSON_MIME,
                    fileName,
                )
                ?: return false
            // "wt" = 기존 내용 지우고 씀 (남은 꼬리가 JSON 을 깨지 않게)
            activity.contentResolver.openOutputStream(fileUri, "wt")?.use { stream ->
                stream.write(content.toByteArray(Charsets.UTF_8))
            } ?: return false
            true
        } catch (error: Exception) {
            DiagnosticLog.write(activity, "backup", "write failed $error")
            false
        }
    }

    private fun clearFolder() {
        savedTreeUri()?.let { releasePermission(it) }
        prefs().edit().remove(KEY_TREE_URI).apply()
        DiagnosticLog.write(activity, "backup", "folder cleared")
    }

    /** 폴더를 바꿨으면 옛 폴더 권한 반납 (영구 권한 개수 제한) */
    private fun releasePreviousFolder(next: Uri) {
        val previous = savedTreeUri() ?: return
        if (previous != next) releasePermission(previous)
    }

    private fun releasePermission(treeUri: Uri) {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (error: Exception) {
            // 이미 없는 권한이면 그대로 진행 (기록만)
            DiagnosticLog.write(activity, "backup", "folder permission release failed $error")
        }
    }

    private fun hasWritePermission(treeUri: Uri): Boolean =
        activity.contentResolver.persistedUriPermissions.any {
            it.uri == treeUri && it.isWritePermission
        }

    private fun directoryDocumentUri(treeUri: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )

    /** 폴더 바로 아래에서 이름이 같은 파일 찾기 */
    private fun findChild(treeUri: Uri, fileName: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        )
        activity.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == fileName) {
                    return DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(0))
                }
            }
        }
        return null
    }

    private fun queryDisplayName(documentUri: Uri): String? = try {
        activity.contentResolver.query(
            documentUri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
    } catch (error: Exception) {
        // 이름을 못 읽어도 폴더는 씀 (URI 끝자리로 대신 표시)
        DiagnosticLog.write(activity, "backup", "folder name query failed $error")
        null
    }

    private fun savedTreeUri(): Uri? = prefs().getString(KEY_TREE_URI, null)?.let(Uri::parse)

    private fun prefs() = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
