import '../core/diagnostics/diagnostics.dart';
import '../core/domain/alert_sound.dart';
import '../features/alert/domain/alert_effects.dart';
import '../features/sounds/domain/custom_sound_repository.dart';

/// 장소가 지정한 알림음을 **재생 가능한 소스로** 바꾼다 (이슈 #121)
///
/// **`app` 계층에 있는 이유** — `alert` 은 `sounds` 를 import 할 수 없고
/// (규칙 1), 그 반대도 마찬가지다. 둘을 값으로 이어주는 것이 `app` 의 일이다
/// (docs/02-ARCHITECTURE.md).
///
/// **어떤 실패에도 소리를 포기하지 않는다.** 파일이 사라졌거나 저장소
/// 조회가 실패하면 기본음으로 떨어진다 — 사용자가 음원까지 골라둔 알림이
/// 진동만 남는 것은 너무 약한 결과다.
class AlertSoundResolver {
  const AlertSoundResolver(this._customSounds);

  final CustomSoundRepository _customSounds;

  Future<AlertSoundSource> resolve(AlertSound sound) async {
    try {
      switch (sound) {
        case PresetSound(:final preset):
          return AssetSound(preset.assetPath);

        case CustomSoundRef(:final id):
          final path = await _customSounds.resolvePlayablePath(id);
          if (path == null) {
            // **재생 단계가 아니라 여기서 막는다.** 재생 실패는 "재시도
            // 금지" 규칙에 걸려 진동으로 떨어지는데, 파일 부재는 그것과
            // 성격이 다른 실패다 (docs/10-DECISIONS.md 007).
            Diagnostics.log('sound', '음원 파일 없음 id=$id → 기본음으로 재생');
            return _fallback;
          }
          return FileSound(path);
      }
    } on Object catch (error) {
      Diagnostics.log('sound', '음원 해석 실패 → 기본음으로 재생 사유=$error');
      return _fallback;
    }
  }

  static AlertSoundSource get _fallback =>
      AssetSound(SoundPreset.defaultTone.assetPath);
}
