/// 알림 발화 시 오디오 경로 (docs/03-DOMAIN.md 규칙 5)
enum AudioRoute {
  /// 블루투스 이어폰으로 소리 재생 (+ 진동)
  bluetooth,

  /// 진동만. 소리 없음
  silent,
}

/// 오디오 경로 결정 (docs/10-DECISIONS.md 007)
///
/// 문제를 뒤집은 설계다 — "이어폰으로 라우팅"이 아니라
/// **"블루투스가 없으면 재생하지 않는다"**. 스피커 유출 사고는
/// 라우팅 실패가 아니라 연결 확인 없이 재생해서 생긴다.
///
/// 순수 함수라 실기기 없이 전 분기를 테스트할 수 있다.
class AudioRouteDecider {
  const AudioRouteDecider();

  /// 발화 시점에 호출한다 — 미리 판정해두지 않는다.
  /// 사용자가 방금 이어폰을 뺐거나 꽂았을 수 있다.
  AudioRoute decide({
    required bool isBluetoothConnected,
    required bool soundEnabled,
  }) {
    if (isBluetoothConnected && soundEnabled) return AudioRoute.bluetooth;
    // 그 외 전부 진동만 — 어떤 분기로도 스피커 출력은 없다 (F3.7)
    return AudioRoute.silent;
  }

  /// 오디오 세션 설정·재생이 실패했을 때의 폴백.
  ///
  /// 재시도하지 않는다 — 재시도 중 라우팅이 바뀌어 스피커로 새는 것이
  /// 최악이다. 소리를 포기하고 진동으로 떨어진다 (docs/05-PLATFORM.md).
  AudioRoute onPlaybackFailure() => AudioRoute.silent;
}
