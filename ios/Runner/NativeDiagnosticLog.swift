import Foundation

/// iOS 네이티브 진단 로그 (이슈 #231, Android `DiagnosticLog.kt` 와 같은 역할)
///
/// **Dart 가 뜨기 전의 일을 남긴다.** 백그라운드 재실행·권한 변경·위치 갱신 시작은
/// Flutter 엔진이 준비되기 전에 일어날 수 있고, 그때 Dart 로그는 아직 없다.
///
/// **자기 파일에만 쓴다** — `diagnostic.ios.log`. Dart isolate 들과 같은 파일에 쓰면
/// 쓰기가 겹쳐 줄이 깨진다. 진단 화면(`DiagnosticLogReader`)이 시각순으로 합친다.
/// 파일명은 Dart `DiagnosticLogSource.iosNative` 와 계약이다.
///
/// 형식은 Dart 와 같다: `2026-10-08T03:12:26.123Z [tag] message`. 영어로 쓴다.
/// **어떤 호출도 예외를 던지지 않는다** — 로깅이 감시를 죽이면 안 된다.
enum NativeDiagnosticLog {
  private static let fileName = "diagnostic.ios.log"
  /// Dart `FileDiagnosticLogger.defaultMaxBytes` 의 절반 — 네이티브는 줄 수가 적다
  private static let maxBytes: UInt64 = 1024 * 1024
  /// 회전 후 남길 비율 — 상한까지만 자르면 다음 줄에 또 넘는다 (Dart 와 같은 이유)
  private static let keepRatio = 0.7

  /// 여러 스레드에서 부른다 — 한 큐로 줄 세운다
  private static let queue = DispatchQueue(label: "kr.suhsaechan.ear_loc_alert.native_log")

  private static let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  static func write(_ tag: String, _ message: String) {
    let now = Date()
    queue.async {
      guard let url = fileURL() else { return }
      let flat = message.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
      let line = "\(formatter.string(from: now)) [\(tag)] \(flat)\n"
      guard let data = line.data(using: .utf8) else { return }
      do {
        if !FileManager.default.fileExists(atPath: url.path) {
          try data.write(to: url)
        } else {
          let handle = try FileHandle(forWritingTo: url)
          defer { try? handle.close() }
          try handle.seekToEnd()
          try handle.write(contentsOf: data)
        }
        rotateIfNeeded(url)
      } catch {
        // 로그를 못 남기는 것은 불편이지 고장이 아니다
      }
    }
  }

  /// path_provider 의 `getApplicationSupportDirectory()` 와 같은 곳 — 한쪽을 바꾸면 반대쪽도 바꾼다
  private static func fileURL() -> URL? {
    guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent(fileName)
  }

  /// 상한을 넘으면 오래된 앞부분을 버린다. 줄 중간에서 자르지 않는다
  private static func rotateIfNeeded(_ url: URL) {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          let size = attributes[.size] as? UInt64, size > maxBytes,
          let data = try? Data(contentsOf: url) else { return }
    let keep = Int(Double(maxBytes) * keepRatio)
    var tail = data.suffix(keep)
    if let newline = tail.firstIndex(of: UInt8(ascii: "\n")) {
      tail = tail.suffix(from: tail.index(after: newline))
    }
    try? Data(tail).write(to: url, options: .atomic)
  }
}
