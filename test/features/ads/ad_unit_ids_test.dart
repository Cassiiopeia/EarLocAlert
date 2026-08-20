import 'package:ear_loc_alert/core/config/dev_flag.dart';
import 'package:ear_loc_alert/features/ads/domain/ad_unit_ids.dart';
import 'package:flutter_test/flutter_test.dart';

/// 광고 단위 ID 선택 (이슈 #109)
///
/// **실제 광고가 잘못 나가면 되돌릴 수 없다.** 무효 트래픽은 누적되고,
/// 계정이 정지되면 이 계정으로 만든 다른 앱의 수익도 함께 끊긴다.
/// 그래서 "언제 실제 광고를 쓰는가"는 반드시 테스트로 고정한다.
void main() {
  tearDown(() => DevFlag.overrideValue(null));

  test('빌드 성격을 읽지 못하면 테스트 광고다', () {
    DevFlag.overrideValue(null);

    // 확신이 없으면 테스트 광고 — 광고가 안 나가는 것은 수익 손실이지만
    // 검증 중 실제 광고가 나가는 것은 계정 정지다
    expect(AdUnitIds.usingTestIds, isTrue);
  });

  test('검증 빌드(DEV_FLAG=true)는 테스트 광고다', () {
    DevFlag.overrideValue(true);

    expect(AdUnitIds.usingTestIds, isTrue);
  });

  test('DevFlag 기본 상태에서 실제 광고가 나가지 않는다', () {
    // init 을 부르지 않은 상태 = 앱 시작 직후. 이때 광고가 뜰 일은 없지만,
    // 만약 뜬다면 테스트 광고여야 한다
    DevFlag.overrideValue(null);

    expect(AdUnitIds.interstitial, contains('3940256099942544'));
  });

  test('배포 빌드임이 확인됐을 때만 실제 단위를 쓴다', () {
    DevFlag.overrideValue(false);

    // 테스트 러너는 debug 모드라 kDebugMode 가 true → 여전히 테스트 ID다.
    // **이 테스트가 확인하는 것은 분기 조건이지 실제 값이 아니다** —
    // 릴리스 빌드에서만 갈리는 값을 단위 테스트로 확정할 수는 없다
    expect(DevFlag.isReleaseBuildConfirmed, isTrue);
    expect(DevFlag.isDevBuild, isFalse);
  });

  test('세 상태가 서로 배타적이다', () {
    DevFlag.overrideValue(true);
    expect(DevFlag.isDevBuild, isTrue);
    expect(DevFlag.isReleaseBuildConfirmed, isFalse);

    DevFlag.overrideValue(false);
    expect(DevFlag.isDevBuild, isFalse);
    expect(DevFlag.isReleaseBuildConfirmed, isTrue);

    // 못 읽은 상태 — **양쪽 다 false 인 것이 핵심이다.**
    // 이분법이면 못 읽은 경우가 어느 한쪽에 붙어 반드시 위험해진다
    DevFlag.overrideValue(null);
    expect(DevFlag.isDevBuild, isFalse);
    expect(DevFlag.isReleaseBuildConfirmed, isFalse);
  });
}
