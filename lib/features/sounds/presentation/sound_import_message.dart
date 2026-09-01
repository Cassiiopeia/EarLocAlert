import '../domain/sound_validator.dart';

/// 등록 실패 문구 (이슈 #121)
///
/// **구체적인 숫자를 함께 보여준다.** "파일이 올바르지 않습니다" 로
/// 뭉뚱그리면 사용자는 무엇을 고쳐야 할지 모른다 — 5MB 를 넘었는지,
/// 형식이 안 맞는지, 개수가 찼는지에 따라 다음 행동이 완전히 다르다.
///
/// 문구를 도메인이 아니라 여기 두는 것은 `place_empty_state.dart` 의
/// `placeErrorMessage` 와 같은 배치다.
String soundImportErrorMessage(SoundImportError error) => switch (error) {
  SoundLimitReached() =>
    '음원은 최대 ${SoundLimits.maxCount}개까지 등록할 수 있습니다. '
        '쓰지 않는 음원을 지우고 다시 시도해주세요.',
  UnsupportedSoundFormat(:final extension) =>
    extension.isEmpty
        ? '확장자가 없는 파일입니다. ${_allowedList()} 형식만 쓸 수 있습니다.'
        : '$extension 형식은 쓸 수 없습니다. ${_allowedList()} 만 가능합니다.',
  SoundTooLarge(:final bytes) =>
    '파일이 너무 큽니다 (${formatBytes(bytes)} / 최대 '
        '${formatBytes(SoundLimits.maxBytes)}).',
  SoundTooLong(:final duration) =>
    '너무 깁니다 (${formatDuration(duration)} / 최대 '
        '${formatDuration(SoundLimits.maxDuration)}). '
        '알림음은 반복 재생되므로 짧아도 됩니다.',
  SoundNotPlayable() => '재생할 수 없는 파일입니다. 다른 파일을 골라주세요.',
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
String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds < 60) {
    return '0:${totalSeconds.toString().padLeft(2, '0')}';
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes분 $seconds초';
}
