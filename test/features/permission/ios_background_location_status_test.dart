import 'package:ear_loc_alert/features/permission/data/permission_handler_service.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_kind.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS "항상" 위치 상태 보정 (이슈 #216)
///
/// 플러그인이 "앱을 사용하는 동안" 직후의 "항상"을 영구 거부로 보고해서, 시스템 창이
/// 한 번도 뜨지 않고 설정으로 보내졌다. 이 판정이 그 단계를 되살린다.
void main() {
  PermissionStatus status({
    PermissionStatus reported = PermissionStatus.permanentlyDenied,
    PermissionStatus whenInUse = PermissionStatus.granted,
    bool asked = false,
  }) => iosBackgroundLocationStatus(
    reported: reported,
    whenInUse: whenInUse,
    alreadyAsked: asked,
  );

  test('앱 사용 중 허용 직후, 아직 안 물었으면 요청 가능으로 본다', () {
    expect(status(), PermissionStatus.denied);
    expect(status().canRequestAgain, isTrue);
  });

  test('이미 물었으면 영구 거부 그대로 둬 설정으로 보낸다', () {
    expect(status(asked: true), PermissionStatus.permanentlyDenied);
  });

  test('앱 사용 중 허용이 없으면 보정하지 않는다 — 위치부터 먼저다', () {
    expect(
      status(whenInUse: PermissionStatus.denied),
      PermissionStatus.permanentlyDenied,
    );
  });

  test('항상이 이미 허용됐으면 그대로 허용이다', () {
    expect(
      status(reported: PermissionStatus.granted),
      PermissionStatus.granted,
    );
  });

  test('제한됨(restricted)은 건드리지 않는다', () {
    expect(
      status(reported: PermissionStatus.restricted),
      PermissionStatus.restricted,
    );
  });
}
