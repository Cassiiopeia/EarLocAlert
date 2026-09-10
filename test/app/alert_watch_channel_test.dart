import 'package:ear_loc_alert/app/background/alert_watch_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 감시 서비스 채널 (이슈 #130)
///
/// **`isAlerting` 이 실패했을 때 무엇을 돌려주는지가 중요하다.**
/// `true` 로 잘못 답하면 멀쩡히 울리고 있는 알림을 앱이 꺼버린다 —
/// 도착 알림이 조용해지는 것은 이 앱에서 가장 나쁜 결과다.
/// 반대로 `false` 로 틀리면 정리를 한 번 건너뛸 뿐이고, 다음 기회에 다시 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kr.suhsaechan.ear_loc_alert/alert_window');
  const service = AlertWatchChannel();

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('isAlerting', () {
    test('네이티브가 울리고 있다고 하면 true', () async {
      mock((call) async => call.method == 'isAlerting' ? true : null);

      expect(await service.isAlerting(), isTrue);
    });

    test('울리지 않으면 false', () async {
      mock((call) async => false);

      expect(await service.isAlerting(), isFalse);
    });

    test('채널이 실패하면 false 로 본다', () async {
      mock((call) async => throw PlatformException(code: 'unavailable'));

      expect(
        await service.isAlerting(),
        isFalse,
        reason: 'true 로 틀리면 멀쩡히 울리는 알림을 앱이 꺼버린다',
      );
    });

    test('구현되지 않은 플랫폼에서도 false', () async {
      mock((call) async => throw MissingPluginException());

      expect(await service.isAlerting(), isFalse);
    });

    test('null 을 돌려받아도 false', () async {
      mock((call) async => null);

      expect(await service.isAlerting(), isFalse);
    });
  });

  group('제어 호출은 예외를 올리지 않는다', () {
    test('채널이 죽어 있어도 감시 시작이 앱을 멈추지 않는다', () async {
      mock((call) async => throw PlatformException(code: 'boom'));

      // 서비스를 못 띄우는 것은 알림이 약해지는 일이지 앱이 멈출 일이 아니다
      await expectLater(service.startWatching(), completes);
      await expectLater(service.stopNativeAlert(), completes);
      await expectLater(service.syncGeofences(const []), completes);
    });
  });
}
