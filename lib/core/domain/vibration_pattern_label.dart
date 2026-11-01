import '../l10n/l10n.dart';
import 'vibration_pattern.dart';

/// 진동 패턴 > 화면 표시 이름 (#311). 설정·장소 폼이 함께 써서 core 에 둔다
extension VibrationPatternLabel on VibrationPattern {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    VibrationPattern.standard => l10n.vibrationPatternStandard,
    VibrationPattern.doubleTap => l10n.vibrationPatternDoubleTap,
    VibrationPattern.tripleTap => l10n.vibrationPatternTripleTap,
    VibrationPattern.heartbeat => l10n.vibrationPatternHeartbeat,
    VibrationPattern.longShort => l10n.vibrationPatternLongShort,
    VibrationPattern.shortLong => l10n.vibrationPatternShortLong,
    VibrationPattern.sos => l10n.vibrationPatternSos,
    VibrationPattern.rapid => l10n.vibrationPatternRapid,
    VibrationPattern.wave => l10n.vibrationPatternWave,
    VibrationPattern.crescendo => l10n.vibrationPatternCrescendo,
    VibrationPattern.knock => l10n.vibrationPatternKnock,
    VibrationPattern.waltz => l10n.vibrationPatternWaltz,
    VibrationPattern.siren => l10n.vibrationPatternSiren,
    VibrationPattern.longPulse => l10n.vibrationPatternLongPulse,
  };
}
