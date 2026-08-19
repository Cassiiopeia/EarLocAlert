import 'dart:async';

import 'package:vibration/vibration.dart';

import '../domain/alert_effects.dart';
import '../domain/vibration_intensity.dart';

/// 반복 진동 구현 (F3.1)
///
/// 사용자가 해제할 때까지 지속한다 (F3.6). 타이머는 반드시 정리한다 —
/// 남아 있으면 해제 후에도 진동이 계속된다.
class VibrationServiceImpl implements VibrationService {
  Timer? _timer;

  @override
  Future<void> startRepeating({
    required Duration interval,
    VibrationIntensity intensity = VibrationIntensity.normal,
  }) async {
    await stop();

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    // 진폭 제어가 없는 기기에서 amplitude 를 넘기면 무시되거나 오류가 된다.
    // 그 경우 길이만으로 세기를 표현한다 (이슈 #103)
    var canControlAmplitude = false;
    try {
      canControlAmplitude = await Vibration.hasAmplitudeControl() == true;
    } on Object {
      // 조회 실패는 미지원으로 본다 — 진동 자체는 계속된다
    }

    Future<void> pulse() async {
      try {
        if (canControlAmplitude) {
          await Vibration.vibrate(
            duration: intensity.pulseMs,
            amplitude: intensity.amplitude,
          );
        } else {
          await Vibration.vibrate(duration: intensity.pulseMs);
        }
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
