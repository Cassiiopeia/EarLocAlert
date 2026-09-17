import 'package:ear_loc_alert/core/audio/headphone_detector.dart';
import 'package:ear_loc_alert/features/alert/data/alert_sound_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림음 해제 경로 (이슈 #136)
///
/// **포커스 반납 자체는 단위 테스트로 확인할 수 없다.** `setActive` 는
/// `Platform.isAndroid` 분기 안에서 `AndroidAudioManager` 를 부르는데,
/// 테스트는 데스크톱 VM 에서 돌아 그 분기에 들어가지 않는다. 실기기
/// 검증 항목이다.
///
/// 여기서 지키는 것은 **해제가 무슨 일이 있어도 완료된다**는 계약이다.
/// 반납을 추가하면서 거기서 예외가 새면 진동이 멎지 않는다 — 이슈 #130
/// 에서 겪은 것과 같은 상태가 된다.
class _FakeDetector implements HeadphoneDetector {
  @override
  Future<bool> isConnected() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('재생한 적이 없어도 해제가 완료된다', () async {
    final service = AlertSoundServiceImpl(detector: _FakeDetector());

    await expectLater(service.stop(), completes);
  });

  test('연달아 해제해도 완료된다', () async {
    final service = AlertSoundServiceImpl(detector: _FakeDetector());

    await service.stop();

    await expectLater(
      service.stop(),
      completes,
      reason: '대기열 처리나 재시도로 두 번 불릴 수 있다',
    );
  });
}
