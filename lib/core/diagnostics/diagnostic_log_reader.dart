import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'diagnostic_log_file.dart';
import 'log_archive.dart';

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
      // **보관본을 먼저 이어 붙인다** (이슈 #127) — 회전으로 넘어간
      // 기록도 화면에서 보여야 한다. 시간순이라 오래된 쪽이 앞이다
      final older = await LogArchive.readArchive(
        await DiagnosticLogFile.resolveArchive(),
      );
      final file = await DiagnosticLogFile.resolve();
      if (!await file.exists()) return (content: older, error: '');
      final current = decodeTolerant(await file.readAsBytes());
      return (content: '$older$current', error: '');
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
      final archive = await DiagnosticLogFile.resolveArchive();
      if (await archive.exists()) await archive.delete();
    } on Object {
      // 지우기 실패는 삼킨다 — 다시 읽으면 실제 상태가 보인다
    }
  }

  /// 지금 기록 파일이 차지하는 바이트. 없으면 0.
  ///
  /// 화면에 보여준다 — **저장공간을 얼마나 쓰는지 사용자가 알아야**
  /// 지울지 말지 판단할 수 있다.
  static Future<int> sizeInBytes() async {
    try {
      final file = await DiagnosticLogFile.resolve();
      return await file.exists() ? await file.length() : 0;
    } on Object {
      return 0;
    }
  }

  /// 내보내기용 스냅샷을 캐시에 만든다 (이슈 #110).
  ///
  /// **원본을 그대로 공유할 수 없다.** 이유가 둘이다.
  ///
  /// 1. `share_plus` 의 FileProvider 는 `{캐시}/share_plus/` 하나만
  ///    공유하도록 선언되어 있다. 기록 파일이 있는 `files/` 는 그 범위 밖이라
  ///    받는 앱이 URI 를 열지 못한다 — 첨부는 되는데 다운로드가 실패했다
  /// 2. **공유하는 동안에도 기록은 계속 쌓인다.** 메일 앱이 나중에 읽으려
  ///    할 때 파일이 이미 달라져 있다
  ///
  /// 확장자를 `.txt` 로 두는 것도 의도적이다. `.log` 는 알려진 MIME 이 없어
  /// 받는 앱이 열기를 꺼린다.
  ///
  /// 내용은 관대하게 디코딩한 뒤 다시 쓴다 — 깨진 바이트가 정리되어
  /// 어디서나 열리는 파일이 된다.
  static Future<File> createExportSnapshot({DateTime? now}) async {
    final content = (await read()).content;
    final stamp = _stamp(now ?? DateTime.now());

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/earlocalert-log-$stamp.txt');
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// `20260820-0955` — 파일명에 쓸 지역 시각.
  ///
  /// 여러 번 내보낸 파일이 섞이지 않게 한다. UTC 가 아닌 이유는 이 값이
  /// 저장용이 아니라 **사람이 보고 고르는 이름**이기 때문이다.
  static String _stamp(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}';
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
