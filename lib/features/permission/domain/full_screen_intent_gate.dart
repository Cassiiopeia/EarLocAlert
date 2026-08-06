import 'permission_kind.dart';

/// 전체화면 알림 권한 접근 (이슈 #74)
///
/// `permission_handler` 가 다루지 않는 권한이라 별도 포트로 둔다.
/// Android 14+ 는 `USE_FULL_SCREEN_INTENT` 를 매니페스트에 선언해도
/// 알람·통화 계열이 아닌 앱에는 자동 부여하지 않는다 — 사용자가 설정
/// 화면에서 직접 켜야 한다 (docs/10-DECISIONS.md 006 재검토).
///
/// **플랫폼 API 를 인터페이스 뒤에 둔다** (docs/02-ARCHITECTURE.md 규칙 3).
abstract interface class FullScreenIntentGate {
  /// 현재 상태.
  ///
  /// 개념이 없는 플랫폼(iOS)·버전(Android 13 이하)에서는
  /// [PermissionStatus.granted] 를 돌려준다 — 막고 있는 것이 없다는 뜻이다.
  Future<PermissionStatus> status();

  /// 설정 화면을 연다. 앱 내 다이얼로그로는 받을 수 없다.
  Future<void> openSettings();
}

/// 이 플랫폼에는 해당 개념이 없다 — 항상 허용으로 본다
class AlwaysGrantedFullScreenIntentGate implements FullScreenIntentGate {
  const AlwaysGrantedFullScreenIntentGate();

  @override
  Future<PermissionStatus> status() async => PermissionStatus.granted;

  @override
  Future<void> openSettings() async {}
}
