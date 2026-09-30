import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/features/app_update/domain/app_updater.dart';

/// 앱 내 업데이트 (이슈 #170) — 알림 화면을 가리지 않고, 너무 자주 묻지 않는다
class _FakeUpdater implements AppUpdater {
  _FakeUpdater({this.available = true, this.downloads = true});

  final bool available;
  final bool downloads;
  int checks = 0;
  int downloaded = 0;

  @override
  Future<bool> updateAvailable() async {
    checks++;
    return available;
  }

  @override
  Future<bool> download() async {
    downloaded++;
    return downloads;
  }

  @override
  Future<void> install() async {}
}

void main() {
  test('새 버전을 받으면 안내 대상이다', () async {
    final updater = _FakeUpdater();
    final outcome = await AppUpdateGate(
      updater,
    ).checkWhenIdle(alertActive: () => false);

    expect(outcome, AppUpdateOutcome.downloaded);
    expect(updater.downloaded, 1);
  });

  test('알림이 울리는 중이면 확인도 하지 않는다', () async {
    final updater = _FakeUpdater();
    final outcome = await AppUpdateGate(
      updater,
    ).checkWhenIdle(alertActive: () => true);

    expect(outcome, AppUpdateOutcome.skippedAlertActive);
    expect(updater.checks, 0);
  });

  test('받는 동안 알림이 울렸으면 안내를 내지 않는다 — 해제 버튼이 가려진다', () async {
    var active = false;
    final updater = _FakeUpdater();
    final gate = AppUpdateGate(updater);
    // 확인 시점엔 조용하다가 받은 뒤에 울린 상황
    final outcome = await gate.checkWhenIdle(
      alertActive: () {
        final now = active;
        active = true;
        return now;
      },
    );

    expect(outcome, AppUpdateOutcome.skippedAlertActive);
    expect(updater.downloaded, 1);
  });

  test('새 버전이 없으면 받지 않는다', () async {
    final updater = _FakeUpdater(available: false);
    final outcome = await AppUpdateGate(
      updater,
    ).checkWhenIdle(alertActive: () => false);

    expect(outcome, AppUpdateOutcome.none);
    expect(updater.downloaded, 0);
  });

  test('받기가 실패하면 안내하지 않는다', () async {
    final outcome = await AppUpdateGate(
      _FakeUpdater(downloads: false),
    ).checkWhenIdle(alertActive: () => false);

    expect(outcome, AppUpdateOutcome.none);
  });

  test('간격 안에서는 다시 묻지 않고, 지나면 다시 묻는다', () async {
    var clock = DateTime(2026, 9, 30, 9);
    final updater = _FakeUpdater(available: false);
    final gate = AppUpdateGate(updater, now: () => clock);

    await gate.checkWhenIdle(alertActive: () => false);
    clock = clock.add(const Duration(hours: 1));
    final recent = await gate.checkWhenIdle(alertActive: () => false);
    expect(recent, AppUpdateOutcome.skippedRecent);
    expect(updater.checks, 1);

    clock = clock.add(const Duration(hours: 6));
    await gate.checkWhenIdle(alertActive: () => false);
    expect(updater.checks, 2);
  });
}
