import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// F3.7 — 어떤 경우에도 기기 스피커로 소리를 내지 않는다.
/// 이 테스트가 깨지면 출시하지 않는다 (docs/01-REQUIREMENTS.md A-05, A-06).
void main() {
  const decider = AudioRouteDecider();

  group('오디오 경로 결정 (docs/03-DOMAIN.md 규칙 5)', () {
    test('이어폰 연결 + 소리 허용 → 이어폰 재생', () {
      expect(
        decider.decide(isHeadphoneConnected: true, soundEnabled: true),
        AudioRoute.headphones,
      );
    });

    test('이어폰 연결 + 소리 꺼짐 → 진동만', () {
      expect(
        decider.decide(isHeadphoneConnected: true, soundEnabled: false),
        AudioRoute.silent,
      );
    });

    test('이어폰 미연결 → 소리 설정과 무관하게 진동만', () {
      expect(
        decider.decide(isHeadphoneConnected: false, soundEnabled: true),
        AudioRoute.silent,
      );
      expect(
        decider.decide(isHeadphoneConnected: false, soundEnabled: false),
        AudioRoute.silent,
      );
    });

    test('재생 실패 폴백은 항상 진동 — 재시도 없음 (docs/10-DECISIONS.md 007)', () {
      expect(decider.onPlaybackFailure(), AudioRoute.silent);
    });

    test('전 분기에서 스피커 출력 경로가 존재하지 않는다 (F3.7)', () {
      // AudioRoute 에 speaker 값 자체가 없다 — 타입 수준에서 차단된다.
      // 이 테스트는 enum 에 speaker 가 추가되는 것을 막는 가드다.
      expect(AudioRoute.values, [AudioRoute.headphones, AudioRoute.silent]);
    });
  });
}
