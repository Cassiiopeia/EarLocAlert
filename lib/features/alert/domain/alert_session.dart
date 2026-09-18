import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/alert_direction.dart';
import 'audio_route.dart';

part 'alert_session.freezed.dart';

/// 지금 울리고 있는 알림 (docs/03-DOMAIN.md)
///
/// DB 에 저장하지 않는다 — 앱이 죽으면 사라지는 것이 맞다.
/// 장소 정보는 값으로 받는다 — alert 는 places 를 import 하지 않는다
/// (docs/02-ARCHITECTURE.md 규칙 1). AlertDirection 은 core 의 공유 어휘다.
@freezed
abstract class AlertSession with _$AlertSession {
  const factory AlertSession({
    required String placeId,
    required String placeName,
    required AlertDirection direction,

    /// UTC
    required DateTime startedAt,

    /// 발화 시점에 결정된 경로
    required AudioRoute audioRoute,

    /// 장소 좌표와 반경 — 알림 화면의 지도 카드용 (이슈 #142).
    ///
    /// **없을 수 있다.** 이 필드가 없던 버전에서 저장된 알림, 미리보기,
    /// 좌표 복원 실패가 전부 여기로 온다. 그때는 지도 카드를 그리지 않고
    /// 나머지는 그대로 보여준다 — 알림음 하나 때문에 알림 전체를 버리지
    /// 않는 것과 같은 판단이다.
    double? latitude,
    double? longitude,
    int? radiusMeters,
  }) = _AlertSession;

  const AlertSession._();

  /// 지도 카드를 그릴 수 있는가.
  ///
  /// 셋 중 하나라도 없으면 그리지 않는다 — 반경 없이 줌을 정할 수 없고,
  /// 좌표 하나만으로는 중심을 잡을 수 없다.
  bool get hasMapLocation =>
      latitude != null && longitude != null && radiusMeters != null;
}
