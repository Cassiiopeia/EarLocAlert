import 'dart:async';

import 'package:vibration/vibration.dart';

import '../domain/alert_effects.dart';

/// 반복 진동 구현 (F3.1)
///
/// 사용자가 해제할 때까지 지속한다 (F3.6). 타이머는 반드시 정리한다 —
/// 남아 있으면 해제 후에도 진동이 계속된다.
class VibrationServiceImpl implements VibrationService {
  Timer? _timer;

  @override
  Future<void> startRepeating({required Duration interval}) async {
    await stop();

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    Future<void> pulse() async {
      try {
        await Vibration.vibrate(duration: 600);
      } on Object {
        // 개별 진동 실패는 무시한다 — 다음 주기에 다시 시도된다
      }
    }

    await pulse();
    _timer = Timer.periodic(interval, (_) => pulse());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    try {
      await Vibration.cancel();
    } on Object {
      // 중단 실패를 삼킨다 — 해제는 무슨 일이 있어도 완료되어야 한다
    }
  }
}
