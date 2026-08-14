import 'dart:convert';

/// 로그 회전 (이슈 #95)
///
/// **상한을 넘으면 오래된 쪽을 버리고 최근 기록을 남긴다.**
///
/// "계속 쌓인다"를 문자 그대로 구현하면 저장공간을 다 먹는다. 반대로
/// 상한에서 통째로 비우면 문제가 생긴 직후의 기록이 사라진다. 최근 것을
/// 남기는 이유는 **문제는 언제나 방금 일어나기 때문**이다.
///
/// 바이트 기준으로 재는 이유는 한글이 UTF-8 에서 3바이트라 문자 수로
/// 재면 실제 파일 크기가 세 배까지 벌어지기 때문이다.
String trimToLimit(String content, int maxBytes) {
  if (content.isEmpty) return content;
  if (utf8.encode(content).length <= maxBytes) return content;

  final lines = content.split('\n');

  // 뒤에서부터 담는다 — 최근 것이 우선이다
  final kept = <String>[];
  var bytes = 0;

  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    // 줄바꿈 1바이트를 함께 센다
    final lineBytes = utf8.encode(line).length + 1;

    if (bytes + lineBytes > maxBytes) break;

    kept.insert(0, line);
    bytes += lineBytes;
  }

  // 마지막 한 줄이 상한보다 길면 아무것도 담기지 않는다.
  // 그 줄을 잘라 깨뜨리느니 상한을 넘겨서라도 온전히 남긴다 —
  // 깨진 줄은 읽을 수 없고, 빈 로그는 아무 쓸모가 없다.
  if (kept.isEmpty) return lines.last;

  return kept.join('\n');
}
