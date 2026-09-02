import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 진단 로그 파일의 위치 (이슈 #95)
///
/// **세 곳이 같은 파일을 봐야 한다** — 앱 isolate, 감시 서비스가 보유한
/// 백그라운드 엔진(별도 isolate), 그리고 Kotlin 계층. 경로가 어긋나면
/// 가장 알고 싶은 정보(네이티브가 이벤트를 받았는가)가 앱에서 안 보인다.
///
/// Android 에서 `getApplicationSupportDirectory()` 는 `context.filesDir` 를
/// 돌려준다. Kotlin 쪽은 `filesDir` 를 직접 쓰면 같은 곳을 가리킨다 —
/// **한쪽을 바꾸면 반대쪽도 바꿔야 한다.**
///
/// 앱 전용 디렉토리이므로 다른 앱이 읽을 수 없다.
abstract final class DiagnosticLogFile {
  /// Kotlin `AlertWatchService`·`GeofenceReceiver` 와 공유하는 파일명.
  /// 양쪽이 계약이다.
  static const fileName = 'diagnostic.log';

  /// 직전 세대의 압축 보관본 (이슈 #127).
  ///
  /// **회전할 때 버리지 않고 여기로 옮긴다.** 텍스트라 gzip 이 대략
  /// 10:1 로 줄여서, 같은 디스크로 훨씬 오래 보관된다 — 하루 만에
  /// 상한이 차던 것이 2주 이상으로 늘어난다.
  ///
  /// 세대를 하나만 두는 이유는 이 로그의 목적이 **"지금 왜 안 울렸나"**
  /// 를 며칠 안에 추적하는 것이기 때문이다. 서버 로그처럼 장기 보관·감사가
  /// 목적이면 세대를 늘리겠지만, 여기서는 그만큼의 복잡도를 살 이유가 없다.
  ///
  /// Kotlin `DiagnosticLog` 와 공유하는 이름이다 — 양쪽이 계약이다.
  static const archiveFileName = 'diagnostic.1.log.gz';

  static Future<File> resolve() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<File> resolveArchive() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$archiveFileName');
  }
}
