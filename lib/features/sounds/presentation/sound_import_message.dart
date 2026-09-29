import '../../../core/l10n/l10n.dart';
import '../domain/sound_validator.dart';

/// 등록 실패 문구 (이슈 #121)
///
/// **구체적인 숫자를 함께 보여준다.** "파일이 올바르지 않습니다" 로
/// 뭉뚱그리면 사용자는 무엇을 고쳐야 할지 모른다 — 5MB 를 넘었는지,
/// 형식이 안 맞는지, 개수가 찼는지에 따라 다음 행동이 완전히 다르다.
///
/// 문구를 도메인이 아니라 여기 두는 것은 `place_empty_state.dart` 의
/// `placeErrorMessage` 와 같은 배치다.
String soundImportErrorMessage(AppLocalizations l10n, SoundImportError error) =>
    switch (error) {
      SoundLimitReached() => l10n.soundImportLimitReached(SoundLimits.maxCount),
      UnsupportedSoundFormat(:final extension) =>
        extension.isEmpty
            ? l10n.soundImportNoExtension(_allowedList())
            : l10n.soundImportUnsupported(extension, _allowedList()),
      SoundTooLarge(:final bytes) => l10n.soundImportTooLarge(
        formatBytes(bytes),
        formatBytes(SoundLimits.maxBytes),
      ),
      SoundTooLong(:final duration) => l10n.soundImportTooLong(
        formatDuration(l10n, duration),
        formatDuration(l10n, SoundLimits.maxDuration),
      ),
      SoundNotPlayable() => l10n.soundImportNotPlayable,
    };

String _allowedList() {
  final sorted = SoundLimits.allowedExtensions.toList()..sort();
  return sorted.join(', ');
}

/// `8.2MB` · `640KB` 처럼 읽기 쉬운 크기.
///
/// 소수점 한 자리까지만 — 사용자가 알아야 하는 것은 "상한을 넘었는가"이지
/// 정확한 바이트 수가 아니다.
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)}MB';
  if (bytes >= kb) return '${(bytes / kb).round()}KB';
  return '$bytes B';
}

/// `0:03` · `1분 12초`
String formatDuration(AppLocalizations l10n, Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds < 60) {
    return '0:${totalSeconds.toString().padLeft(2, '0')}';
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return l10n.soundDurationMinutesSeconds(minutes, seconds);
}
