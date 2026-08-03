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
  }) = _AlertSession;
}
