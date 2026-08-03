import 'permission_kind.dart';
import 'permission_snapshot.dart';

/// 플랫폼 권한 접근 (docs/02-ARCHITECTURE.md 규칙 3)
///
/// 화면은 이 인터페이스만 본다. `permission_handler` 를 직접 부르지 않으므로
/// 판정 흐름을 실기기 없이 테스트할 수 있다.
abstract interface class PermissionService {
  /// 현재 상태를 읽는다 (요청하지 않는다)
  Future<PermissionSnapshot> check();

  /// 권한을 요청하고 갱신된 상태를 돌려준다.
  ///
  /// Android API 30+ 의 `backgroundLocation` 은 앱 내 다이얼로그로 받을 수
  /// 없다 — 구현이 시스템 설정 화면을 여는 것으로 대체한다
  /// (docs/05-PLATFORM.md).
  Future<PermissionSnapshot> request(PermissionKind kind);

  /// 앱 설정 화면을 연다. 영구 거부 상태에서 유일한 경로다.
  Future<void> openAppSettings();
}
