import 'dart:math' as math;

import '../../../core/domain/vibration_pattern.dart';
import 'vibration_intensity.dart';

export '../../../core/domain/vibration_pattern.dart';

/// 진동 파형: 패턴 × 세기 > `[쉬기, 떨기, …]` ms + 칸별 진폭 (#311)
///
/// Android `createWaveform`·`vibration` 플러그인과 같은 형식이라 세 경로(앱 전면 ·
/// Android 감시 서비스 · iOS 시스템 진동)에 그대로 넘긴다.
class VibrationWaveform {
  const VibrationWaveform({required this.timingsMs, required this.amplitudes});

  /// 짝수 칸 쉬기, 홀수 칸 떨기 (첫 칸은 시작 전 쉼 0)
  final List<int> timingsMs;

  /// [timingsMs] 와 같은 길이. 쉬기 칸은 0, 떨기 칸은 1~255
  final List<int> amplitudes;

  /// 한 주기 전체 길이
  int get totalMs => timingsMs.fold(0, (sum, value) => sum + value);

  /// 떨기 칸의 시작 시각 목록 (iOS 시스템 진동 예약용)
  List<int> get pulseStartOffsetsMs {
    final offsets = <int>[];
    var elapsed = 0;
    for (var index = 0; index < timingsMs.length; index++) {
      if (index.isOdd && timingsMs[index] > 0) offsets.add(elapsed);
      elapsed += timingsMs[index];
    }
    return offsets;
  }

  /// 패턴 × 세기 > 파형. [VibrationPattern.standard] 는 null (기존 단일 진동 경로)
  static VibrationWaveform? build(
    VibrationPattern pattern,
    VibrationIntensity intensity,
  ) {
    if (pattern.beats.isEmpty) return null;
    final timings = <int>[0];
    final amplitudes = <int>[0];
    final scale = _durationScale(intensity);
    for (final beat in pattern.beats) {
      timings.add(math.max(1, (beat.onMs * scale).round()));
      amplitudes.add((intensity.amplitude * beat.level).round().clamp(1, 255));
      timings.add(beat.offMs);
      amplitudes.add(0);
    }
    return VibrationWaveform(timingsMs: timings, amplitudes: amplitudes);
  }

  /// 세기별 떨기 길이 배율: 진폭 제어 없는 기기에서도 세기 차이가 남게 (#103 원칙)
  static double _durationScale(VibrationIntensity intensity) =>
      switch (intensity) {
        VibrationIntensity.weak => 0.8,
        VibrationIntensity.normal => 1.0,
        VibrationIntensity.strong => 1.25,
      };
}

/// 기본 진동 패턴 설정 (#311): 장소에 패턴이 없을 때 쓰는 전역 값
abstract interface class VibrationPatternStore {
  /// 저장된 값이 없으면 [VibrationPattern.standard]
  Future<VibrationPattern> pattern();

  Future<void> save(VibrationPattern pattern);
}
