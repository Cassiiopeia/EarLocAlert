import '../l10n/l10n.dart';
import 'alert_sound.dart';

/// 프리셋의 화면 표시 이름 (이슈 #163)
///
/// 저장은 [SoundPreset.id] 로 하고 이름만 번역한다. enum 이 문구를 들면
/// 언어를 바꿔도 따라 바뀌지 않으므로 화면이 [AppLocalizations] 로 바꾼다.
/// 여러 feature 가 쓰므로 `core` 에 둔다.
extension SoundPresetLabel on SoundPreset {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    SoundPreset.defaultTone => l10n.soundPresetDefault,
    SoundPreset.bell => l10n.soundPresetBell,
    SoundPreset.electronic => l10n.soundPresetElectronic,
    SoundPreset.siren => l10n.soundPresetSiren,
    SoundPreset.chime => l10n.soundPresetChime,
  };
}
