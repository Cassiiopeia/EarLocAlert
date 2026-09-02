import '../../../core/diagnostics/log_format.dart';
import '../../../core/domain/alert_direction.dart';
import 'geofence_state.dart';
import 'geofence_evaluation.dart';
import 'geofence_target.dart';

/// 알림이 나가지 않은 이유 (이슈 #127)
///
/// **"왜 안 울렸는가"가 이 앱에서 가장 자주 묻는 질문이다.** 그런데
/// 그동안 로그는 여섯 가지 서로 다른 상황을 `알림 없음` 한 줄로 뭉갰다.
/// 사용자가 겪은 그 순간은 재현되지 않으므로, 남은 기록이 갈라주지
/// 못하면 영영 알 수 없다.
enum AlertSuppression {
  /// 삭제된 장소의 이벤트가 뒤늦게 도착했다
  placeNotFound,

  /// 사용자가 꺼둔 장소다 — "왜 안 울렸나"의 가장 단순한 답
  placeDisabled,

  /// 상태가 그대로다. 반경 안에 있었고 여전히 안에 있다
  noTransition,

  /// **정확도가 부족해 판정을 미뤘다.**
  ///
  /// 실내·지하·터널에서 자주 일어난다. 이것이 `noTransition` 과
  /// 구분되지 않으면 "GPS 가 나빠서"인지 "움직이지 않아서"인지 알 수 없다.
  deferred,

  /// 전이는 있었으나 장소의 방향 설정과 맞지 않는다
  /// (도착만 켰는데 이탈했다)
  directionMismatch,

  /// 알림 시간 창 밖이다 (이슈 #81)
  outsideSchedule;

  /// 로그에 남길 짧은 한국어. **여기가 단일 출처다** —
  /// 호출부에서 문자열을 조립하면 표현이 갈린다.
  String get label => switch (this) {
    placeNotFound => '장소없음',
    placeDisabled => '장소꺼짐',
    noTransition => '전이없음',
    deferred => '정확도부족',
    directionMismatch => '방향불일치',
    outsideSchedule => '시간대밖',
  };
}

/// 알림을 막은 이유를 돌려준다. **`null` 이면 알린다.**
///
/// `GeofenceEvaluator.shouldNotify` 와 같은 규칙이며, 그쪽이 이 함수를
/// 써서 판정한다 — 규칙이 두 곳에 있으면 반드시 어긋난다.
AlertSuppression? suppressionOf({
  required GeofenceTarget target,
  required GeofenceTransition transition,
  required bool scheduleActive,
}) {
  if (!target.enabled) return AlertSuppression.placeDisabled;

  // **전이 판정이 스케줄보다 먼저다.** 전이가 없으면 시간대를 따질 것도
  // 없고, "시간대밖"으로 기록되면 창을 고치면 울릴 것처럼 오해하게 된다.
  switch (transition) {
    case GeofenceTransition.none:
      return AlertSuppression.noTransition;
    case GeofenceTransition.deferred:
      return AlertSuppression.deferred;
    case GeofenceTransition.entered:
      if (!target.direction.notifiesOnEnter) {
        return AlertSuppression.directionMismatch;
      }
    case GeofenceTransition.exited:
      if (!target.direction.notifiesOnExit) {
        return AlertSuppression.directionMismatch;
      }
  }

  if (!scheduleActive) return AlertSuppression.outsideSchedule;
  return null;
}

/// 판정 결과 한 줄. 순수 함수라 테스트할 수 있다 (이슈 #127).
///
/// 형식을 여기 하나로 모으는 이유는 **로그를 읽는 사람이 형식을 외우기
/// 때문**이다. 호출부마다 조금씩 다르면 눈으로 훑을 수 없다.
String formatDecision({
  required String placeId,
  required String placeName,
  required GeofenceTransition transition,
  required AlertSuppression? suppression,
  AlertDirection? direction,
  double? accuracyMeters,
}) {
  final buffer = StringBuffer()
    // id 는 앞 8자만 — 지오펜스 로그와 대조하기에 충분하고 줄이 짧아진다
    ..write('판정 place=${shortId(placeId)} name=$placeName ')
    ..write('전이=${transition.name} ');

  if (suppression == null) {
    buffer.write('→ 알림 (방향=${direction?.name ?? "?"})');
  } else {
    buffer.write('→ 알림없음 (사유=${suppression.label}');
    // 정확도 부족은 실제 값이 있어야 판단할 수 있다
    if (suppression == AlertSuppression.deferred && accuracyMeters != null) {
      buffer.write(' acc=${meters(accuracyMeters)}');
    }
    if (suppression == AlertSuppression.directionMismatch) {
      buffer.write(' 설정=${direction?.name ?? "?"}');
    }
    buffer.write(')');
  }
  return buffer.toString();
}

/// 상태 전이 한 줄 (이슈 #127).
///
/// **전이는 사실이고 알림은 설정이다** (docs/03-DOMAIN.md). 알림이
/// 안 나가도 전이는 일어났을 수 있으므로 따로 남긴다.
String formatTransition({
  required String placeId,
  required String placeName,
  required GeofenceState from,
  required GeofenceState to,
  double? latitude,
  double? longitude,
  double? accuracyMeters,
}) {
  final buffer = StringBuffer()
    ..write('상태 전이 place=${shortId(placeId)} name=$placeName ')
    ..write('${from.name} → ${to.name}');
  if (latitude != null && longitude != null) {
    buffer.write(' lat=$latitude lng=$longitude');
  }
  if (accuracyMeters != null) {
    buffer.write(' acc=${meters(accuracyMeters)}');
  }
  return buffer.toString();
}
