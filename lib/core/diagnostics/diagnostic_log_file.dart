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

  static Future<File> resolve() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }
}
