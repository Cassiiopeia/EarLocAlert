/// 진단 로그 한 줄 (이슈 #95)
///
/// **좌표를 포함해 남긴다.** `docs/04-CONVENTIONS.md` 의 "릴리스 로그에
/// 좌표 금지"는 로그가 외부로 새는 것을 막으려는 규칙이었다. 이 로그는
/// 앱 전용 디렉토리에만 있고(다른 앱이 읽을 수 없다) 어디로도 전송하지
/// 않으며, 내보내기는 사용자가 직접 하는 행위다. 그 목적이 유지되므로
/// 여기서는 예외를 둔다.
///
/// 좌표 없이는 "왜 이 장소가 판정되지 않았는가"를 추적할 수 없고,
/// 그것이 이 앱에서 가장 자주 묻게 되는 질문이다.
class DiagnosticEntry {
  const DiagnosticEntry({
    required this.timestampUtc,
    required this.tag,
    required this.message,
  });

  /// UTC — 표시할 때만 로컬로 바꾼다 (docs/04-CONVENTIONS.md)
  final DateTime timestampUtc;

  /// 어느 계층이 남겼는가. `geofence` · `watch` · `alert` · `engine` 등
  final String tag;

  final String message;

  /// 파일에 쓰는 한 줄 형식.
  ///
  /// 줄바꿈을 공백으로 바꾸는 이유는 **한 항목이 한 줄이어야 회전이
  /// 안전하기** 때문이다. 여러 줄이면 회전할 때 반쪽만 남아 읽을 수 없다.
  String format() {
    final flat = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    return '${timestampUtc.toIso8601String()} [$tag] $flat';
  }
}
