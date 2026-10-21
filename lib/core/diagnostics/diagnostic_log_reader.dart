import 'dart:convert';
import 'dart:io';

import 'diagnostic_line.dart';
import 'diagnostic_log_file.dart';
import 'log_archive.dart';

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
  /// 모든 주체의 기록 > 시각순 합본 + 출처별 요약 (이슈 #231, #290).
  ///
  /// 한 주체를 못 읽어도 나머지는 보여준다 — 오류는 하나라도 있으면
  /// 함께 돌려줘 "기록 없음"과 구분되게 한다.
  static Future<DiagnosticLogSnapshot> readSnapshot() async {
    final contents = <DiagnosticLogSource, String>{};
    final errors = <DiagnosticLogSource, String>{};
    for (final source in DiagnosticLogSource.values) {
      try {
        contents[source] = await _readSource(source);
      } on Object catch (failure) {
        contents[source] = '';
        errors[source] = '$failure';
      }
    }
    final lines = mergeLines(contents);
    final sources = [
      for (final source in DiagnosticLogSource.values)
        await _summarize(source, lines, errors[source] ?? ''),
    ];
    return DiagnosticLogSnapshot(
      lines: lines,
      sources: sources,
      error: [
        for (final entry in errors.entries) '${entry.key.name}: ${entry.value}',
      ].join('; '),
    );
  }

  /// 출처 1개 요약: 파일·보관본 크기 + 합본에서 센 줄 수·기간
  static Future<DiagnosticSourceSummary> _summarize(
    DiagnosticLogSource source,
    List<DiagnosticLine> lines,
    String error,
  ) async {
    final own = [
      for (final line in lines)
        if (line.source == source && line.hasTimestamp) line,
    ];
    return DiagnosticSourceSummary(
      source: source,
      fileBytes: await _lengthOrZero(await DiagnosticLogFile.resolve(source)),
      archiveBytes: await _lengthOrZero(
        await DiagnosticLogFile.resolveArchive(source),
      ),
      lineCount: lines.where((line) => line.source == source).length,
      firstAt: own.isEmpty ? null : own.first.at,
      lastAt: own.isEmpty ? null : own.last.at,
      error: error,
    );
  }

  static Future<int> _lengthOrZero(File? file) async {
    try {
      if (file == null || !await file.exists()) return 0;
      return await file.length();
    } on Object {
      // 못 잰 파일은 0 (요약 줄의 error 로 이미 드러남)
      return 0;
    }
  }

  /// 한 주체의 보관본 + 현재 파일. **보관본이 먼저다** (이슈 #127) —
  /// 회전으로 넘어간 기록도 시간순으로 이어져야 한다.
  static Future<String> _readSource(DiagnosticLogSource source) async {
    final archive = await DiagnosticLogFile.resolveArchive(source);
    final older = archive == null ? '' : await LogArchive.readArchive(archive);
    final file = await DiagnosticLogFile.resolve(source);
    if (!await file.exists()) return older;
    return '$older${decodeTolerant(await file.readAsBytes())}';
  }

  /// 여러 파일의 기록을 시각순으로 합친다 (이슈 #231, 출처 보존 #290).
  ///
  /// 각 파일은 이미 시간순이다 — 한 주체가 순서대로 쓰기 때문이다. 줄 앞의
  /// ISO-8601 시각으로 정렬하되, **시각을 읽을 수 없는 줄(예전에 깨진 줄)은
  /// 같은 파일의 바로 앞 줄 시각을 물려받는다.** 그래야 깨진 줄이 맨 앞이나
  /// 맨 뒤로 튀지 않고 원래 자리 근처에 남는다.
  ///
  /// 시각이 같으면 출처 순서 → 줄 순서로 정한다 — 결과가 결정적이어야
  /// 같은 기록을 두 번 열었을 때 순서가 바뀌지 않는다.
  ///
  /// 문자열 비교가 아니라 시각으로 파싱해 비교한다. Dart 는 마이크로초
  /// (`.123456Z`), Kotlin·Swift 는 밀리초(`.123Z`)로 써서 문자열로 비교하면
  /// 같은 밀리초 안에서 순서가 뒤집힌다.
  static List<DiagnosticLine> mergeLines(
    Map<DiagnosticLogSource, String> contents,
  ) {
    final entries = <_MergeEntry>[];
    for (final MapEntry(key: source, value: content) in contents.entries) {
      final lines = content.split('\n');
      var carried = _epoch;
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trim().isEmpty) continue;
        final at = _timestampOf(line);
        if (at != null) carried = at;
        entries.add(_MergeEntry(carried, source, index, line));
      }
    }
    entries.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      final bySource = a.source.index.compareTo(b.source.index);
      if (bySource != 0) return bySource;
      return a.index.compareTo(b.index);
    });
    return [
      for (final entry in entries)
        DiagnosticLine(source: entry.source, at: entry.at, raw: entry.line),
    ];
  }

  static final _epoch = DateTime.utc(1970);

  /// 줄 앞의 시각. 공백 앞까지가 시각이고 `Z` 로 끝나야 한다 — 깨진 줄
  /// 조각이 우연히 숫자로 시작해도 시각으로 오인하지 않는다.
  static DateTime? _timestampOf(String line) {
    final space = line.indexOf(' ');
    if (space < 20) return null;
    final head = line.substring(0, space);
    if (!head.endsWith('Z')) return null;
    return DateTime.tryParse(head);
  }

  /// 깨진 바이트가 섞여 있어도 읽어낸다 (이슈 #106).
  ///
  /// #231 이전에는 여러 주체가 한 파일에 append 해 쓰기가 겹치면 한글
  /// 한 글자(UTF-8 3바이트)가 중간에서 잘렸다. 지금은 파일을 나눴지만
  /// 그때 기록과 보관본이 남아 있으므로 계속 견뎌야 한다.
  ///
  /// `readAsString()` 은 그 순간 통째로 예외를 던지고, 예전 구현은 그것을
  /// 삼켜 **"기록 없음"으로 둔갑시켰다.** 파일에 수천 줄이 있어도 화면은
  /// 0건이었다 — 한 글자 때문에 전부를 잃는 것은 어떤 기준으로도 손해다.
  ///
  /// `allowMalformed` 는 깨진 바이트를 대체 문자(U+FFFD)로 바꾼다.
  /// 그 줄 하나만 이상해 보이고 나머지는 그대로 읽힌다.
  static String decodeTolerant(List<int> bytes) {
    final text = const Utf8Decoder(allowMalformed: true).convert(bytes);
    return stripNulRuns(text);
  }

  /// NUL(0x00) 덩어리를 표식 한 줄로 바꾼다 (이슈 #239).
  ///
  /// iOS 에서 앱이 기록을 쓰던 중 종료되면 파일 끝이 0 바이트로 채워질 수
  /// 있다. 그 NUL 이 문자열에 남으면 **클립보드·붙여넣기가 거기서 문자열을
  /// 끝낸다** — 실기기에서 복사한 기록이 매번 같은 줄 중간에서 끊기고, 시각순
  /// 병합 때문에 그 뒤의 모든 기록(이후 실행 포함)이 통째로 사라졌다.
  ///
  /// 지우기만 하지 않고 표식을 남긴다 — "이 지점에서 앱이 기록 중 끝났다"는
  /// 것 자체가 비정상 종료를 추적하는 단서다. 앞뒤를 줄바꿈으로 감싸서 뒤에
  /// 이어 붙은 기록이 잘린 줄에 섞이지 않고 제 줄로 돌아온다.
  static String stripNulRuns(String text) {
    if (!text.contains('\u0000')) return text;
    return text.replaceAllMapped(
      _nulRun,
      (match) => '\n$nulMarker bytes=${match.group(0)!.length}\n',
    );
  }

  /// 기록이 끊긴 자리에 남기는 표식 — 영어 고정 토큰 (CLAUDE.md 로그 규칙)
  static const nulMarker = '[diag] log write interrupted (null bytes removed)';

  static final _nulRun = RegExp('\u0000+');

  /// 파일을 비운다. 없으면 아무것도 하지 않는다.
  ///
  /// 로거의 `clear()` 와 별개로 필요하다 — 초기화되지 않은 로거는
  /// 지우기도 하지 않기 때문이다.
  static Future<void> clear() async {
    for (final source in DiagnosticLogSource.values) {
      try {
        final file = await DiagnosticLogFile.resolve(source);
        if (await file.exists()) await file.writeAsString('');
        final archive = await DiagnosticLogFile.resolveArchive(source);
        if (archive != null && await archive.exists()) await archive.delete();
      } on Object {
        // 지우기 실패는 삼킨다 — 다시 읽으면 실제 상태가 보인다
      }
    }
  }

  /// 지금 기록 파일이 차지하는 바이트. 없으면 0.
  ///
  /// 화면에 보여준다 — **저장공간을 얼마나 쓰는지 사용자가 알아야**
  /// 지울지 말지 판단할 수 있다.
  static Future<int> sizeInBytes() async {
    var total = 0;
    for (final source in DiagnosticLogSource.values) {
      try {
        final file = await DiagnosticLogFile.resolve(source);
        if (await file.exists()) total += await file.length();
      } on Object {
        // 못 잰 파일은 0 으로 본다
      }
    }
    return total;
  }
}

/// 합치기용 한 줄 — 정렬 키(시각·파일·줄 번호)와 원문
class _MergeEntry {
  _MergeEntry(this.at, this.source, this.index, this.line);

  final DateTime at;
  final DiagnosticLogSource source;
  final int index;
  final String line;
}
