import 'dart:convert';

import 'diagnostic_log_file.dart';

/// 진단 기록 읽기 결과 (이슈 #106)
///
/// **"기록 없음"과 "읽지 못함"을 구분한다.** 둘은 완전히 다른 상황인데
/// 하나로 뭉뚱그리면, 파일을 못 읽는 중에 "아직 기록이 없습니다"를 본
/// 사용자가 감시가 안 도는 줄 알고 없는 문제를 찾게 된다.
typedef DiagnosticReadResult = ({String content, String error});

/// 기록 파일을 직접 읽는다 (이슈 #106)
///
/// **`Diagnostics.logger` 를 거치지 않는 것이 핵심이다.** 그 로거는 앱
/// 시작 시 `init()` 이 성공해야 파일 로거가 되고, 실패하면 아무것도 하지
/// 않는 로거로 남는다. 그 상태에서 `readAll()` 은 무조건 빈 문자열이라
/// **파일에 네이티브가 남긴 기록이 잔뜩 있어도 화면은 0건으로 보인다.**
///
/// 진단 화면이 진단 대상의 초기화 성공에 의존하면 안 된다 — 정확히
/// 그것이 실패했을 때 열리는 화면이다.
abstract final class DiagnosticLogReader {
  static Future<DiagnosticReadResult> read() async {
    try {
      final file = await DiagnosticLogFile.resolve();
      if (!await file.exists()) return (content: '', error: '');
      return (content: decodeTolerant(await file.readAsBytes()), error: '');
    } on Object catch (failure) {
      return (content: '', error: '$failure');
    }
  }

  /// 깨진 바이트가 섞여 있어도 읽어낸다 (이슈 #106).
  ///
  /// **이 파일은 두 프로세스가 함께 쓴다** — 앱 isolate·감시 서비스 엔진
  /// (Dart)과 Kotlin 계층이 같은 파일에 append 한다. 쓰기가 겹치면 한글
  /// 한 글자(UTF-8 3바이트)가 중간에서 잘릴 수 있다.
  ///
  /// `readAsString()` 은 그 순간 통째로 예외를 던지고, 예전 구현은 그것을
  /// 삼켜 **"기록 없음"으로 둔갑시켰다.** 파일에 수천 줄이 있어도 화면은
  /// 0건이었다 — 한 글자 때문에 전부를 잃는 것은 어떤 기준으로도 손해다.
  ///
  /// `allowMalformed` 는 깨진 바이트를 대체 문자(U+FFFD)로 바꾼다.
  /// 그 줄 하나만 이상해 보이고 나머지는 그대로 읽힌다.
  static String decodeTolerant(List<int> bytes) {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }

  /// 파일을 비운다. 없으면 아무것도 하지 않는다.
  ///
  /// 로거의 `clear()` 와 별개로 필요하다 — 초기화되지 않은 로거는
  /// 지우기도 하지 않기 때문이다.
  static Future<void> clear() async {
    try {
      final file = await DiagnosticLogFile.resolve();
      if (await file.exists()) await file.writeAsString('');
    } on Object {
      // 지우기 실패는 삼킨다 — 다시 읽으면 실제 상태가 보인다
    }
  }

  /// 표시할 줄 목록. **최근 것이 위로 온다.**
  ///
  /// 빈 줄은 버린다 — 회전이나 외부 편집으로 섞여 들어올 수 있고,
  /// 건수에 세면 실제보다 많아 보인다.
  static List<String> linesOf(String content) {
    return content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList()
        .reversed
        .toList();
  }
}
