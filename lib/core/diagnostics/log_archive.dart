import 'dart:io';

import 'diagnostic_log_reader.dart';

/// 로그 압축 보관 (이슈 #127)
///
/// **회전할 때 버리지 않고 압축해 남긴다.** 예전에는 상한을 넘으면
/// 오래된 30% 를 그냥 지웠고, 그 기록은 영영 사라졌다. 실기기에서
/// 정밀 감시가 도는 날은 **하루 만에 상한이 차서** 전날 기록을 볼 수 없었다.
///
/// 텍스트라 gzip 이 대략 10:1 로 줄인다. 회전은 드물게 일어나므로
/// 압축 비용도 드물다 — 백그라운드 판정 경로에 부담이 되지 않는다.
abstract final class LogArchive {
  /// 현재 로그를 통째로 압축해 [archive] 에 저장하고, 원본을 비운다.
  ///
  /// **직전 세대를 덮어쓴다.** 세대를 늘리면 관리가 늘어나는데, 이 로그의
  /// 목적은 며칠 안의 추적이라 두 세대면 충분하다.
  ///
  /// 실패하면 `false` — 호출자는 예전 방식(잘라내기)으로 떨어진다.
  /// **압축에 실패했다고 로그 파일이 무한정 자라면 안 된다.**
  static Future<bool> rotate({
    required File source,
    required File archive,
  }) async {
    try {
      final bytes = await source.readAsBytes();
      if (bytes.isEmpty) return true;

      await archive.writeAsBytes(gzip.encode(bytes), flush: true);
      await source.writeAsString('', flush: true);
      return true;
    } on Object {
      return false;
    }
  }

  /// 보관본을 풀어 읽는다. 없거나 깨졌으면 빈 문자열.
  ///
  /// **깨진 보관본이 현재 로그까지 막으면 안 된다** — 진단 화면은
  /// 무슨 일이 있어도 지금 기록을 보여줘야 한다.
  static Future<String> readArchive(File archive) async {
    try {
      if (!await archive.exists()) return '';
      final raw = gzip.decode(await archive.readAsBytes());
      // 압축 전에 이미 깨진 바이트가 있을 수 있다 (두 프로세스가 함께 쓴다)
      return DiagnosticLogReader.decodeTolerant(raw);
    } on Object {
      return '';
    }
  }
}
