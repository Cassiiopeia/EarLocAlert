/// 진동 한 박자: 떨기 길이 > 쉬기 길이, 상대 세기 (#311)
class VibrationBeat {
  const VibrationBeat(this.onMs, this.offMs, [this.level = 1.0]);

  /// 떠는 길이 (세기 배율 적용 전)
  final int onMs;

  /// 다음 박자까지 쉬는 길이 (마지막 박자는 다음 주기까지의 쉼)
  final int offMs;

  /// 상대 세기 0~1 (세기 설정 진폭에 곱함)
  final double level;
}

/// 진동 패턴 (#311): places·alert·app 공통이라 core 에 둔다 (AlertSound 와 같은 자리)
///
/// 저장은 이름으로 한다 — 순서 인덱스면 값을 끼워 넣는 순간 기존 설정이 바뀐다.
/// [standard] 만 무료이고 박자 없이 기존 단일 진동 경로를 탄다.
enum VibrationPattern {
  standard([]),
  doubleTap([VibrationBeat(120, 120), VibrationBeat(120, 1000)]),
  tripleTap([
    VibrationBeat(100, 100),
    VibrationBeat(100, 100),
    VibrationBeat(100, 1000),
  ]),
  heartbeat([VibrationBeat(90, 120), VibrationBeat(180, 1000, 0.7)]),
  longShort([VibrationBeat(600, 150), VibrationBeat(150, 1000)]),
  shortLong([VibrationBeat(150, 150), VibrationBeat(600, 1000)]),
  sos([
    VibrationBeat(100, 100),
    VibrationBeat(100, 100),
    VibrationBeat(100, 250),
    VibrationBeat(300, 100),
    VibrationBeat(300, 100),
    VibrationBeat(300, 250),
    VibrationBeat(100, 100),
    VibrationBeat(100, 100),
    VibrationBeat(100, 900),
  ]),
  rapid([
    VibrationBeat(60, 60),
    VibrationBeat(60, 60),
    VibrationBeat(60, 60),
    VibrationBeat(60, 60),
    VibrationBeat(60, 60),
    VibrationBeat(60, 1000),
  ]),
  wave([
    VibrationBeat(250, 50, 0.35),
    VibrationBeat(250, 50, 0.7),
    VibrationBeat(300, 50, 1.0),
    VibrationBeat(250, 1000, 0.5),
  ]),
  crescendo([
    VibrationBeat(150, 150, 0.25),
    VibrationBeat(150, 150, 0.5),
    VibrationBeat(150, 150, 0.75),
    VibrationBeat(200, 1000, 1.0),
  ]),
  knock([
    VibrationBeat(70, 350),
    VibrationBeat(70, 120),
    VibrationBeat(70, 1000),
  ]),
  waltz([
    VibrationBeat(250, 200),
    VibrationBeat(100, 200, 0.5),
    VibrationBeat(100, 1000, 0.5),
  ]),
  siren([
    VibrationBeat(350, 0, 0.4),
    VibrationBeat(350, 0, 1.0),
    VibrationBeat(350, 0, 0.4),
    VibrationBeat(350, 1000, 1.0),
  ]),
  longPulse([VibrationBeat(1500, 1000)]);

  const VibrationPattern(this.beats);

  /// 비어 있으면 기존 단일 진동 (세기의 pulseMs 한 번)
  final List<VibrationBeat> beats;

  /// 무료에서도 고를 수 있는 패턴인가 (#311)
  bool get isFree => this == standard;

  /// 저장값 > 패턴. 모르는 값·null 은 null (호출자가 기본 패턴으로 대체)
  static VibrationPattern? tryParse(String? name) {
    for (final pattern in values) {
      if (pattern.name == name) return pattern;
    }
    return null;
  }

  /// 저장값 > 패턴. 깨진 값은 [standard] (알림은 울려야 함)
  static VibrationPattern fromName(String? name) =>
      tryParse(name) ?? VibrationPattern.standard;
}
