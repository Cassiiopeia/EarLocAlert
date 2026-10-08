import 'dart:async';

import 'package:vibration/vibration.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/alert_effects.dart';
import '../domain/vibration_intensity.dart';

/// 화면 없이 도는 동안 쓰는 시스템 진동 (이슈 #235)
///
/// `vibration` 플러그인은 iOS 에서 Core Haptics 로 떤다. Core Haptics 는 앱이
/// 백그라운드에 있으면 재생되지 않는다 — v1.26.2 실기기에서 세션은 돌았는데
/// 앱을 열 때까지 한 번도 떨지 않았다. 그 사이에는 이것으로 떤다.
abstract interface class SystemVibration {
  /// 지금 이것으로 떨어야 하는가 (iOS 이고 앱이 전면이 아님)
  bool shouldUse();

  /// 진동 한 번. 소리는 내지 않는다
  Future<void> pulse();
}

/// 반복 진동 구현 (F3.1)
///
/// 사용자가 해제할 때까지 지속한다 (F3.6). 타이머는 반드시 정리한다 —
/// 남아 있으면 해제 후에도 진동이 계속된다.
///
/// 진동 한 번마다 경로를 다시 고른다 (이슈 #235) — 백그라운드에서 시작한
/// 세션도 사용자가 앱을 열면 세기 조절이 되는 햅틱으로 넘어가야 한다.
class VibrationServiceImpl implements VibrationService {
  VibrationServiceImpl({
    SystemVibration? system,
    Future<bool> Function()? hasVibrator,
    Future<bool> Function()? hasAmplitudeControl,
    Future<void> Function(int durationMs, int? amplitude)? vibrate,
    Future<void> Function()? cancel,
  }) : _system = system,
       _hasVibrator = hasVibrator ?? _pluginHasVibrator,
       _hasAmplitudeControl = hasAmplitudeControl ?? _pluginHasAmplitude,
       _vibrate = vibrate ?? _pluginVibrate,
       _cancel = cancel ?? Vibration.cancel;

  final SystemVibration? _system;
  final Future<bool> Function() _hasVibrator;
  final Future<bool> Function() _hasAmplitudeControl;
  final Future<void> Function(int durationMs, int? amplitude) _vibrate;
  final Future<void> Function() _cancel;

  Timer? _timer;

  /// 마지막으로 쓴 경로 — 바뀔 때만 기록한다. 매 진동마다 남기면 로그가 묻힌다
  String? _route;

  /// 시스템 진동 실패를 한 번만 남긴다 — 주기마다 같은 오류가 쌓이지 않게
  bool _systemFailureLogged = false;

  @override
  Future<void> startRepeating({
    required Duration interval,
    VibrationIntensity intensity = VibrationIntensity.normal,
  }) async {
    await stop();
    _route = null;
    _systemFailureLogged = false;

    // 시스템 진동이 있으면 플러그인 조회 결과와 무관하게 떤다 — 백그라운드에서
    // 플러그인이 "진동기 없음"을 돌려줘도 진동 자체를 포기하지 않는다
    var hasVibrator = false;
    try {
      hasVibrator = await _hasVibrator();
    } on Object {
      // 조회 실패는 없음으로 본다
    }
    if (!hasVibrator && _system == null) return;

    // 진폭 제어가 없는 기기에서 amplitude 를 넘기면 무시되거나 오류가 된다.
    // 그 경우 길이만으로 세기를 표현한다 (이슈 #103)
    var canControlAmplitude = false;
    try {
      canControlAmplitude = await _hasAmplitudeControl();
    } on Object {
      // 조회 실패는 미지원으로 본다 — 진동 자체는 계속된다
    }

    Future<void> pulse() async {
      final system = _system;
      if (system != null && system.shouldUse()) {
        _noteRoute('system');
        try {
          await system.pulse();
        } on Object catch (error) {
          if (!_systemFailureLogged) {
            _systemFailureLogged = true;
            Diagnostics.log('alert', 'system vibration failed error=$error');
          }
        }
        return;
      }
      if (!hasVibrator) return;
      _noteRoute('haptics');
      try {
        await _vibrate(
          intensity.pulseMs,
          canControlAmplitude ? intensity.amplitude : null,
        );
      } on Object {
        // 개별 진동 실패는 무시한다 — 다음 주기에 다시 시도된다
      }
    }

    await pulse();
    _timer = Timer.periodic(interval, (_) => pulse());
  }

  void _noteRoute(String route) {
    if (_route == route) return;
    final from = _route ?? 'none';
    _route = route;
    Diagnostics.log('alert', 'vibration route=$route from=$from');
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    try {
      await _cancel();
    } on Object {
      // 중단 실패를 삼킨다 — 해제는 무슨 일이 있어도 완료되어야 한다
    }
  }

  static Future<bool> _pluginHasVibrator() async =>
      await Vibration.hasVibrator() == true;

  static Future<bool> _pluginHasAmplitude() async =>
      await Vibration.hasAmplitudeControl() == true;

  static Future<void> _pluginVibrate(int durationMs, int? amplitude) =>
      amplitude == null
      ? Vibration.vibrate(duration: durationMs)
      : Vibration.vibrate(duration: durationMs, amplitude: amplitude);
}
