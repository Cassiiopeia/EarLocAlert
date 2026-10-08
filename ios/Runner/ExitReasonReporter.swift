import Foundation
import MetricKit

/// 앱이 왜 죽었는지 다음 실행 때 진단 기록에 남긴다 (이슈 #241)
///
/// **진단 기록은 앱이 죽은 순간 끊긴다.** v1.27.x 실기기에서 도착 세션이 시작되고
/// 1초 뒤 기록이 줄 중간에서 끊겼고, 진동도 없었다 — 크래시인지, 메모리 초과로
/// 시스템이 죽였는지 남은 것이 없어 가를 수 없었다. Android 의
/// `getHistoricalProcessExitReasons`(이슈 #134)에 해당하는 것이 iOS 에서는 MetricKit 이다.
///
/// - **크래시 진단**(`MXCrashDiagnostic`)은 iOS 15+ 에서 다음 실행 때 곧바로 온다
/// - **종료 사유 집계**(`MXAppExitMetric`)는 하루 한 번 온다 — 메모리 초과·워치독·
///   백그라운드 작업 시간 초과처럼 크래시 보고가 없는 종료가 여기 잡힌다
///
/// 같은 보고를 두 번 남기지 않도록 마지막으로 남긴 보고의 끝 시각을 기억한다.
/// **어떤 호출도 예외를 던지지 않는다** — 진단이 앱을 멈추면 안 된다.
final class ExitReasonReporter: NSObject, MXMetricManagerSubscriber {
  static let shared = ExitReasonReporter()

  private static let lastReportedKey = "exit_reason_last_reported_end"

  /// 호출 스택 JSON 은 수십 KB 가 된다 — 진단 기록 한 줄에 담을 만큼만 남긴다
  private static let maxStackChars = 3000

  private override init() {}

  /// 앱 시작 때 한 번 부른다. 이미 도착해 있던 보고(지난 24시간)도 읽는다 —
  /// 구독 전에 도착한 크래시 보고를 놓치지 않기 위해서다
  func start() {
    MXMetricManager.shared.add(self)
    if #available(iOS 14.0, *) {
      handle(diagnostics: MXMetricManager.shared.pastDiagnosticPayloads, source: "past")
    }
  }

  // MARK: - MXMetricManagerSubscriber

  func didReceive(_ payloads: [MXMetricPayload]) {
    for payload in payloads {
      guard isNew(payload.timeStampEnd) else { continue }
      if #available(iOS 14.0, *), let exits = payload.applicationExitMetrics {
        logExits(exits, begin: payload.timeStampBegin, end: payload.timeStampEnd)
      }
      remember(payload.timeStampEnd)
    }
  }

  @available(iOS 14.0, *)
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    handle(diagnostics: payloads, source: "delivered")
  }

  // MARK: - 기록

  @available(iOS 14.0, *)
  private func handle(diagnostics payloads: [MXDiagnosticPayload], source: String) {
    for payload in payloads {
      guard isNew(payload.timeStampEnd) else { continue }
      let window = "from=\(Self.stamp(payload.timeStampBegin)) to=\(Self.stamp(payload.timeStampEnd))"
      for crash in payload.crashDiagnostics ?? [] {
        logCrash(crash, window: window, source: source)
      }
      // 크래시가 아닌 진단은 개수만 — 무엇이 있었는지 알면 다음 조사를 정할 수 있다
      let hangs = payload.hangDiagnostics?.count ?? 0
      let cpu = payload.cpuExceptionDiagnostics?.count ?? 0
      let disk = payload.diskWriteExceptionDiagnostics?.count ?? 0
      if hangs + cpu + disk > 0 {
        NativeDiagnosticLog.write(
          "exit",
          "diagnostics received source=\(source) hangs=\(hangs) cpu=\(cpu) disk_write=\(disk) \(window)"
        )
      }
      remember(payload.timeStampEnd)
    }
  }

  @available(iOS 14.0, *)
  private func logCrash(_ crash: MXCrashDiagnostic, window: String, source: String) {
    let meta = crash.metaData
    let type = crash.exceptionType.map { "\($0)" } ?? "none"
    let code = crash.exceptionCode.map { "\($0)" } ?? "none"
    let signal = crash.signal.map { "\($0)" } ?? "none"
    let reason = Self.flatten(crash.terminationReason ?? "none")
    NativeDiagnosticLog.write(
      "exit",
      "crash reported source=\(source) app=\(meta.applicationBuildVersion) os=\(meta.osVersion) "
        + "exception_type=\(type) exception_code=\(code) signal=\(signal) reason=\(reason) \(window)"
    )
    // 어디서 죽었는지는 호출 스택에 있다 — 잘라서라도 남긴다
    let json = String(data: crash.callStackTree.jsonRepresentation(), encoding: .utf8) ?? ""
    NativeDiagnosticLog.write(
      "exit",
      "crash stack \(Self.flatten(String(json.prefix(Self.maxStackChars))))"
    )
  }

  @available(iOS 14.0, *)
  private func logExits(_ exits: MXAppExitMetric, begin: Date, end: Date) {
    let fg = exits.foregroundExitData
    let bg = exits.backgroundExitData
    // 0 이 아닌 사유만 — 대부분 0 이라 전부 쓰면 읽을 수 없다
    let background: [(String, Int)] = [
      ("normal", bg.cumulativeNormalAppExitCount),
      ("memory_limit", bg.cumulativeMemoryResourceLimitExitCount),
      ("memory_pressure", bg.cumulativeMemoryPressureExitCount),
      ("cpu_limit", bg.cumulativeCPUResourceLimitExitCount),
      ("watchdog", bg.cumulativeAppWatchdogExitCount),
      ("bad_access", bg.cumulativeBadAccessExitCount),
      ("illegal_instruction", bg.cumulativeIllegalInstructionExitCount),
      ("abnormal", bg.cumulativeAbnormalExitCount),
      ("locked_file", bg.cumulativeSuspendedWithLockedFileExitCount),
      ("task_timeout", bg.cumulativeBackgroundTaskAssertionTimeoutExitCount),
    ]
    let foreground: [(String, Int)] = [
      ("normal", fg.cumulativeNormalAppExitCount),
      ("memory_limit", fg.cumulativeMemoryResourceLimitExitCount),
      ("watchdog", fg.cumulativeAppWatchdogExitCount),
      ("bad_access", fg.cumulativeBadAccessExitCount),
      ("illegal_instruction", fg.cumulativeIllegalInstructionExitCount),
      ("abnormal", fg.cumulativeAbnormalExitCount),
    ]
    NativeDiagnosticLog.write(
      "exit",
      "exit counts background=[\(Self.describe(background))] foreground=[\(Self.describe(foreground))] "
        + "from=\(Self.stamp(begin)) to=\(Self.stamp(end))"
    )
  }

  // MARK: - 중복 방지

  private func isNew(_ end: Date) -> Bool {
    let last = UserDefaults.standard.double(forKey: Self.lastReportedKey)
    return end.timeIntervalSince1970 > last
  }

  /// 보고가 늦게 섞여 와도 뒤로 가지 않게 큰 값만 남긴다
  private func remember(_ end: Date) {
    let last = UserDefaults.standard.double(forKey: Self.lastReportedKey)
    if end.timeIntervalSince1970 > last {
      UserDefaults.standard.set(end.timeIntervalSince1970, forKey: Self.lastReportedKey)
    }
  }

  // MARK: - 형식

  private static func describe(_ counts: [(String, Int)]) -> String {
    let nonZero = counts.filter { $0.1 > 0 }.map { "\($0.0)=\($0.1)" }
    return nonZero.isEmpty ? "none" : nonZero.joined(separator: ",")
  }

  private static func flatten(_ text: String) -> String {
    text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
  }

  private static let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  private static func stamp(_ date: Date) -> String {
    formatter.string(from: date)
  }
}
