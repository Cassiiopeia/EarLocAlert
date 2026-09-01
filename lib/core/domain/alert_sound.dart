/// 알림음 — 장소마다 다르게 고른다 (이슈 #121)
///
/// `places` 가 고르고 `alert` 이 재생한다. 두 feature 가 공유하는 어휘라
/// `core/domain` 에 둔다 (docs/02-ARCHITECTURE.md 규칙 1 — feature 끼리
/// 직접 import 하지 않는다).
library;

/// 앱이 내장한 알림음.
///
/// **음원 파일이 준비될 때마다 여기에 한 줄, `pubspec.yaml` 의 assets 에
/// 한 줄을 더한다.** enum 이 곧 목록이라 화면 코드는 건드리지 않는다.
///
/// **파일이 실제로 있는 것만 넣는다.** 없는 asset 을 넣으면 재생이
/// 실패해 진동만 남는데, 사용자는 자기가 고른 소리가 왜 안 나는지 알 수 없다.
enum SoundPreset {
  /// 지금까지의 알림음. 기존 장소는 마이그레이션 후에도 이 소리다.
  defaultTone('default', '기본음', 'assets/sounds/alert.wav');

  // 음원을 받으면 아래를 되살린다 (CC0/PD 만 — ATTRIBUTION.md 에 출처 기록)
  // bell('bell', '종소리', 'assets/sounds/bell.wav'),
  // electronic('electronic', '전자음', 'assets/sounds/electronic.wav'),
  // siren('siren', '사이렌', 'assets/sounds/siren.wav'),
  // chime('chime', '차임', 'assets/sounds/chime.wav');

  const SoundPreset(this.id, this.label, this.assetPath);

  /// 저장에 쓰는 식별자. **순서(인덱스)가 아니라 이름으로 저장한다** —
  /// 프리셋을 중간에 끼워 넣어도 기존 사용자 설정이 안 바뀐다.
  final String id;

  /// 화면에 보여주는 이름
  final String label;

  final String assetPath;

  /// 모르는 id 는 기본음으로 흡수한다.
  ///
  /// 앱을 이전 버전으로 되돌려 설치하면 저장된 값이 아직 없는 프리셋을
  /// 가리킬 수 있다. 그때 알림이 멎으면 안 된다.
  static SoundPreset fromId(String? id) =>
      values.firstWhere((preset) => preset.id == id, orElse: () => defaultTone);
}

/// 장소에 지정된 알림음.
///
/// 저장 형식은 문자열 하나다 — `preset:<id>` 또는 `custom:<uuid>`.
/// Drift 컬럼 하나로 끝나고, 프리셋을 늘려도 스키마가 바뀌지 않는다.
sealed class AlertSound {
  const AlertSound();

  /// 알 수 없는 값이 왔을 때 떨어지는 곳
  static const AlertSound fallback = PresetSound(SoundPreset.defaultTone);

  /// **절대 던지지 않는다.** 깨진 값은 [fallback] 으로 떨어진다 —
  /// 문자열 하나 때문에 알림이 멎으면 안 된다.
  factory AlertSound.parse(String raw) {
    final separator = raw.indexOf(':');
    if (separator <= 0) return fallback;

    final kind = raw.substring(0, separator);
    final value = raw.substring(separator + 1);

    return switch (kind) {
      'preset' => PresetSound(SoundPreset.fromId(value)),
      // uuid 가 비어 있으면 가리키는 파일이 없다 — 기본음이 맞다
      'custom' when value.isNotEmpty => CustomSoundRef(value),
      _ => fallback,
    };
  }

  /// DB 에 저장하는 문자열
  String get storageValue;
}

/// 내장 음원을 가리킨다
final class PresetSound extends AlertSound {
  const PresetSound(this.preset);

  final SoundPreset preset;

  @override
  String get storageValue => 'preset:${preset.id}';

  @override
  bool operator ==(Object other) =>
      other is PresetSound && other.preset == preset;

  @override
  int get hashCode => preset.hashCode;

  @override
  String toString() => 'PresetSound(${preset.id})';
}

/// 사용자가 올린 음원을 **id 로만** 가리킨다.
///
/// 이름·길이·크기를 가진 실체는 `features/sounds` 의 `CustomSound` 다.
/// 여기에 파일 경로를 담지 않는 이유는 [CustomSoundRef.id] 문서 참조.
final class CustomSoundRef extends AlertSound {
  const CustomSoundRef(this.id);

  /// uuid. **절대경로가 아니다.**
  ///
  /// 경로를 저장하면 앱 재설치·OS 업데이트로 컨테이너 경로가 바뀌었을 때
  /// 전부 죽는다. 경로는 재생 직전에 조립한다
  /// (`DiagnosticLogFile.resolve` 와 같은 방식).
  final String id;

  @override
  String get storageValue => 'custom:$id';

  @override
  bool operator ==(Object other) => other is CustomSoundRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CustomSoundRef($id)';
}
