import Flutter
import UIKit
import UniformTypeIdentifiers

/// 자동 백업 폴더 (#314): 사용자가 고른 폴더(iCloud Drive·내 iPhone)에 백업 파일 덮어쓰기
///
/// 폴더 접근은 보안 범위 북마크로 유지 (UserDefaults). 앱을 지우면 북마크도 사라지지만 파일은 남음.
/// 메서드 4개: pickFolder, folderName, write(fileName, content), clearFolder
final class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  static let shared = BackupFolderChannel()

  private static let channelName = "kr.suhsaechan.ear_loc_alert/backup_folder"
  // UserDefaults: 고른 폴더 보안 범위 북마크
  private static let bookmarkKey = "auto_backup.folder_bookmark"

  /// 폴더 고르기 응답 대기 (한 번에 하나)
  private var pendingPick: FlutterResult?

  func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "pickFolder":
          self.pickFolder(result: result)
        case "folderName":
          result(self.resolveFolder()?.lastPathComponent)
        case "write":
          let args = call.arguments as? [String: Any]
          guard let fileName = args?["fileName"] as? String,
            let content = args?["content"] as? String
          else {
            result(FlutterError(code: "bad_args", message: "fileName and content required", details: nil))
            return
          }
          result(self.write(fileName: fileName, content: content))
        case "clearFolder":
          UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
          NativeDiagnosticLog.write("backup", "folder cleared")
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  private func pickFolder(result: @escaping FlutterResult) {
    guard pendingPick == nil else {
      result(FlutterError(code: "busy", message: "folder picker already open", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      NativeDiagnosticLog.write("backup", "folder picker failed reason=no_view_controller")
      result(nil)
      return
    }
    pendingPick = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    // 고른 직후에만 접근이 열려 있음: 이때 북마크를 만들어야 다음 실행에도 씀
    let didStart = url.startAccessingSecurityScopedResource()
    defer { if didStart { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
      NativeDiagnosticLog.write("backup", "folder picked name=\(url.lastPathComponent)")
      result(url.lastPathComponent)
    } catch {
      NativeDiagnosticLog.write("backup", "folder bookmark failed error=\(error.localizedDescription)")
      result(nil)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    NativeDiagnosticLog.write("backup", "folder pick cancelled")
    pendingPick?(nil)
    pendingPick = nil
  }

  /// 북마크 > 폴더 URL. 없거나 깨졌으면 nil (오래된 북마크는 새로 저장)
  private func resolveFolder() -> URL? {
    guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
      if isStale {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
          UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
      }
      return url
    } catch {
      NativeDiagnosticLog.write("backup", "folder bookmark resolve failed error=\(error.localizedDescription)")
      return nil
    }
  }

  /// 폴더 안 [fileName] 덮어쓰기. iCloud 폴더도 되게 파일 조정자를 거침. 실패하면 false
  private func write(fileName: String, content: String) -> Bool {
    guard let folder = resolveFolder() else {
      NativeDiagnosticLog.write("backup", "write skipped reason=no_folder")
      return false
    }
    guard folder.startAccessingSecurityScopedResource() else {
      NativeDiagnosticLog.write("backup", "write skipped reason=permission_lost")
      return false
    }
    defer { folder.stopAccessingSecurityScopedResource() }
    let target = folder.appendingPathComponent(fileName)
    var coordinatorError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordinatorError) { url in
      do {
        try Data(content.utf8).write(to: url, options: .atomic)
      } catch {
        writeError = error
      }
    }
    if let error = coordinatorError ?? writeError {
      NativeDiagnosticLog.write("backup", "write failed error=\(error.localizedDescription)")
      return false
    }
    return true
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
