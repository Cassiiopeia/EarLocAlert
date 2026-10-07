import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 진단 로그를 쓰는 주체 (이슈 #231)
///
/// **쓰는 주체마다 파일을 따로 둔다.** 예전에는 앱 isolate·백그라운드
/// isolate·네이티브가 한 파일(`diagnostic.log`)에 함께 append 했다. 그런데
/// Dart 의 `FileMode.append` 는 `O_APPEND` 가 아니라 "끝으로 이동 → 쓰기"
/// 두 단계라, 두 isolate 가 동시에 쓰면 같은 위치에 겹쳐 써 줄이 잘리거나
/// 사라진다. 실측: 두 isolate 가 3000줄씩 쓰면 142줄이 사라지고 101줄이
/// 깨졌다. iOS 실기기 로그의 `ng=null` 로 시작하는 줄이 그 흔적이다.
///
/// isolate 안의 직렬화로는 막을 수 없고, 파일 잠금(fcntl)은 프로세스 단위라
/// 같은 프로세스의 isolate 끼리는 서로를 막지 못한다. 그래서 파일을 나누고
/// 읽는 쪽([DiagnosticLogReader])이 시각순으로 합친다.
enum DiagnosticLogSource {
  /// 앱 isolate (화면이 있는 엔진)
  app('diagnostic.app.log', 'diagnostic.app.1.log.gz'),

  /// 백그라운드 isolate — Android 감시 서비스 엔진, iOS 지오펜스 콜백 엔진.
  /// 한 플랫폼에서 동시에 둘이 뜨지 않으므로 하나를 같이 쓴다
  background('diagnostic.bg.log', 'diagnostic.bg.1.log.gz'),

  /// Android Kotlin 계층(`DiagnosticLog.kt`)과 #231 이전 Dart 기록.
  ///
  /// **이름을 바꾸지 않는다** — Kotlin 이 이 이름으로 쓰고, 이미 설치된
  /// 기기의 예전 기록도 여기 남아 있다. Dart 는 이제 여기 쓰지 않는다.
  native('diagnostic.log', 'diagnostic.1.log.gz'),

  /// iOS Swift 계층(`NativeDiagnosticLog`). 회전 시 gzip 대신 앞부분을
  /// 잘라내므로 보관본이 없다
  iosNative('diagnostic.ios.log', null);

  const DiagnosticLogSource(this.fileName, this.archiveFileName);

  final String fileName;

  /// 직전 세대의 압축 보관본 (이슈 #127). 없으면 null.
  final String? archiveFileName;
}

/// 진단 로그 파일의 위치 (이슈 #95)
///
/// Android 에서 `getApplicationSupportDirectory()` 는 `context.filesDir` 를,
/// iOS 에서는 `Library/Application Support` 를 돌려준다. 네이티브 쪽도 같은
/// 디렉토리를 써야 한 화면에서 합쳐 읽힌다 — **한쪽을 바꾸면 반대쪽도
/// 바꿔야 한다.**
///
/// 앱 전용 디렉토리이므로 다른 앱이 읽을 수 없다.
abstract final class DiagnosticLogFile {
  /// Kotlin `DiagnosticLog` 와 공유하는 파일명 — 양쪽이 계약이다.
  static final fileName = DiagnosticLogSource.native.fileName;

  /// Kotlin `DiagnosticLog` 와 공유하는 보관본 이름 (이슈 #127)
  ///
  /// 세대를 하나만 두는 이유는 이 로그의 목적이 **"지금 왜 안 울렸나"**
  /// 를 며칠 안에 추적하는 것이기 때문이다.
  static final archiveFileName = DiagnosticLogSource.native.archiveFileName!;

  static Future<File> resolve([
    DiagnosticLogSource source = DiagnosticLogSource.native,
  ]) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/${source.fileName}');
  }

  /// 보관본. 보관본이 없는 주체는 null.
  static Future<File?> resolveArchive([
    DiagnosticLogSource source = DiagnosticLogSource.native,
  ]) async {
    final name = source.archiveFileName;
    if (name == null) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name');
  }
}
