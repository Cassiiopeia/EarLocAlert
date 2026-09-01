import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/domain/alert_direction.dart';
import '../../core/domain/alert_sound.dart';

part 'pending_alert.freezed.dart';

/// 백그라운드에서 발생해 아직 앱이 처리하지 않은 알림 (이슈 #63)
///
/// 백그라운드 isolate 는 콜백 후 즉시 죽어 반복 진동·오디오 세션을
/// 시작할 수 없다. OS 알림만 띄우고 이 값을 남기면, 앱이 열릴 때
/// PendingAlertLauncher 가 풀 알림 세션(AlertController)으로 잇는다.
@freezed
abstract class PendingAlert with _$PendingAlert {
  const factory PendingAlert({
    required String placeId,
    required String placeName,
    required AlertDirection direction,
    required bool soundEnabled,

    /// UTC
    required DateTime occurredAt,

    /// 이 장소에 지정된 알림음 (이슈 #121).
    ///
    /// **필수가 아니다** — 이 값이 없던 버전에서 저장된 값을 읽을 수 있고,
    /// 그때는 기본음으로 울려야 한다.
    @Default(PresetSound(SoundPreset.defaultTone)) AlertSound sound,
  }) = _PendingAlert;
}
