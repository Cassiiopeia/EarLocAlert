import 'package:flutter/foundation.dart';

/// 빌드 성격 (컴파일 상수): 개발 빌드 여부, 개발자 도구 사용 가능 여부 (#359)
/// 값은 `.github/config/build-profile.json` 의 test 프로파일이 `--dart-define=APP_FLAVOR=dev` 로 넣음
abstract final class AppBuildFlavor {
  /// Firebase 테스트 APK·iOS 테스트 TestFlight 빌드인가
  /// Play 트랙(내부·비공개·정식)은 같은 AAB 라 항상 false
  static const bool isDevBuild = String.fromEnvironment('APP_FLAVOR') == 'dev';

  /// 개발자 도구를 쓸 수 있는가 (디버그 실행 또는 개발 빌드)
  /// 컴파일 상수라 스토어 빌드에서는 false 로 접히고 이 값으로 막은 코드는 빌드에서 빠짐
  static const bool canUseDevTools = kDebugMode || isDevBuild;

  /// 진단·로그 표시용 이름: debug / dev / store
  static String get label {
    if (kDebugMode) return 'debug';
    return isDevBuild ? 'dev' : 'store';
  }
}
