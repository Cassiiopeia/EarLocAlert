/// 진단 로그 기록 (이슈 #95)
///
/// **어떤 호출도 예외를 올리지 않는다.** 로그를 못 남기는 것은 불편이지
/// 고장이 아니다. 로깅이 앱을 멈추면 본말이 전도된다 —
/// 특히 백그라운드 경로에서는 그대로 감시가 죽는다.
abstract interface class DiagnosticLogger {
  /// 한 줄을 남긴다.
  ///
  /// 호출자가 `await` 하지 않아도 되도록 설계한다 — 판정 경로에서
  /// 로깅을 기다리면 알림이 늦어진다.
  Future<void> log(String tag, String message);

  /// 쌓인 로그 전체를 읽는다. 없으면 빈 문자열.
  Future<String> readAll();

  /// 로그를 비운다.
  Future<void> clear();
}

/// 아무것도 하지 않는 구현 — 테스트·로깅 비활성 상황용
class NoopDiagnosticLogger implements DiagnosticLogger {
  const NoopDiagnosticLogger();

  @override
  Future<void> log(String tag, String message) async {}

  @override
  Future<String> readAll() async => '';

  @override
  Future<void> clear() async {}
}
