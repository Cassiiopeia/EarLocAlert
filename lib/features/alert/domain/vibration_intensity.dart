/// 진동 세기 (이슈 #103)
///
/// **왜 필요한가** — 이 앱은 이어폰이 연결됐을 때만 소리를 낸다. 즉
/// 대부분의 알림은 진동이 전부다. 그 진동이 주머니에서 안 느껴지면 알림이
/// 실패한 것이고, 조용한 곳에서 책상을 울리면 그것대로 실패다.
///
/// **세기와 길이를 함께 바꾼다.** 진폭 제어(`hasAmplitudeControl`)를
/// 지원하지 않는 기기가 아직 많고, 그런 기기에서 세기 설정이 아무 효과도
/// 없으면 사용자는 설정이 고장 났다고 판단한다. 길이는 어느 기기에서나
/// 통하므로 폴백이 아니라 **함께 가는 축**으로 둔다.
enum VibrationIntensity {
  weak(amplitude: 90, pulseMs: 400),

  /// 기본값. 지금까지의 동작과 같은 세기다 —
  /// 설정을 새로 만들었다고 기존 사용자의 알림이 달라지면 안 된다.
  normal(amplitude: 170, pulseMs: 800),

  strong(amplitude: 255, pulseMs: 1200);

  const VibrationIntensity({required this.amplitude, required this.pulseMs});

  /// 1~255. Android `VibrationEffect` 의 진폭 범위다.
  ///
  /// 0 은 "진동 없음"이라 쓰지 않는다 — 가장 약한 단계도 느껴져야 한다.
  final int amplitude;

  /// 한 번의 진동이 이어지는 길이(ms).
  ///
  /// 진폭 제어가 없는 기기에서는 이것만이 체감 차이를 만든다.
  final int pulseMs;

  static VibrationIntensity fromName(String? name) {
    return VibrationIntensity.values.firstWhere(
      (value) => value.name == name,
      // 저장된 값이 깨졌어도 알림은 울려야 한다
      orElse: () => VibrationIntensity.normal,
    );
  }
}

/// 진동 세기 설정 (이슈 #103)
///
/// 알림음 크기와 같은 전역 설정이다 — 장소별로 두지 않는다. 장소마다
/// 다르면 사용자는 왜 이번엔 약하게 울렸는지 추적해야 한다.
abstract interface class VibrationIntensityStore {
  /// 저장된 값이 없으면 [VibrationIntensity.normal]
  Future<VibrationIntensity> intensity();

  Future<void> save(VibrationIntensity intensity);
}
