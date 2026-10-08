import 'dart:async';

import 'package:ear_loc_alert/app/alert_dismiss_flow.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_session.dart';
import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림을 끈 뒤의 흐름 (이슈 #233, 결정 056)
///
/// 해제 완료 화면을 없애면서 그 화면이 하던 칸막이 역할을 여기서 지킨다 —
/// **해제가 먼저, 광고는 기다리지 않고, 홈이 뜬 뒤 잠깐 쉬고, 다시 울리면 안 낸다.**
void main() {
  final session = AlertSession(
    placeId: 'p1',
    placeName: '테스트 위치',
    direction: AlertDirection.enter,
    startedAt: DateTime.utc(2026, 10, 8),
    audioRoute: AudioRoute.silent,
  );

  late List<String> events;
  late bool ringing;
  late AlertSession? dismissed;

  setUp(() {
    events = [];
    ringing = true;
    dismissed = session;
  });

  // 앞 테스트가 걸어 둔 광고 시도가 다음 테스트의 기록에 섞이지 않게 기다린다
  tearDown(() => Future<void>.delayed(const Duration(milliseconds: 100)));

  AlertDismissFlow flow({
    Future<void> Function()? ad,
    Duration adDelay = const Duration(milliseconds: 30),
  }) => AlertDismissFlow(
    dismiss: () async {
      events.add('dismiss');
      ringing = false;
      return dismissed;
    },
    isRinging: () => ringing,
    goHome: () => events.add('home'),
    returnToSettings: () => events.add('settings'),
    showDismissedToast: () => events.add('toast'),
    tryShowAd:
        ad ??
        () async {
          events.add('ad');
        },
    adDelay: adDelay,
  );

  test('끄면 곧장 홈으로 가고 토스트를 띄운다 — 확인 화면이 없다', () async {
    await flow().run(fromPreview: false);

    expect(events, ['dismiss', 'home', 'toast']);
  });

  test('해제는 광고를 기다리지 않는다 — 광고가 끝나지 않아도 흐름이 끝난다', () async {
    final never = Completer<void>();

    await flow(
      ad: () => never.future,
      adDelay: Duration.zero,
    ).run(fromPreview: false).timeout(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(events.first, 'dismiss', reason: '진동·소리가 먼저 멈춘다');
    expect(events, containsAllInOrder(['dismiss', 'home', 'toast']));
  });

  test('광고는 홈이 뜬 뒤 잠깐 쉬고 나서 시도한다 — 해제하던 엄지가 누르지 않게', () async {
    await flow(
      adDelay: const Duration(milliseconds: 60),
    ).run(fromPreview: false);

    expect(events, isNot(contains('ad')), reason: '쉬는 시간 전에는 내지 않는다');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(events.last, 'ad');
    expect(events.indexOf('ad'), greaterThan(events.indexOf('home')));
  });

  test('기본 쉬는 시간은 0.6~0.8초다', () {
    expect(
      AlertDismissFlow.defaultAdDelay.inMilliseconds,
      inInclusiveRange(600, 800),
    );
  });

  test('쉬는 사이 다른 알림이 울리면 광고를 내지 않는다 — 알림 화면에 겹치지 않는다', () async {
    await flow().run(fromPreview: false);
    ringing = true; // 다음 알림이 도착했다

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(events, isNot(contains('ad')));
  });

  test('줄 서 있던 다른 장소 알림이 이어 울리면 알림 화면에 머문다', () async {
    final target = AlertDismissFlow(
      dismiss: () async {
        events.add('dismiss');
        return session; // 해제는 됐지만 다음 알림이 곧바로 시작됐다
      },
      isRinging: () => true,
      goHome: () => events.add('home'),
      returnToSettings: () => events.add('settings'),
      showDismissedToast: () => events.add('toast'),
      tryShowAd: () async => events.add('ad'),
      adDelay: Duration.zero,
    );

    await target.run(fromPreview: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(events, ['dismiss']);
  });

  test('미리보기는 설정으로 돌아간다 (이슈 #229)', () async {
    await flow().run(fromPreview: true);

    expect(events, ['dismiss', 'home', 'settings', 'toast']);
  });

  test('이미 꺼져 있었으면 홈으로만 간다 — 토스트도 광고도 없다', () async {
    dismissed = null;

    await flow(adDelay: Duration.zero).run(fromPreview: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(events, ['dismiss', 'home']);
  });

  test('광고가 실패해도 아무 일도 없다', () async {
    await flow(
      ad: () async => throw StateError('ad sdk'),
      adDelay: Duration.zero,
    ).run(fromPreview: false);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, ['dismiss', 'home', 'toast']);
  });
}
