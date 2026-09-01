/// 사용자 음원 검증 (이슈 #121)
///
/// 순수 로직 — 파일 시스템 없이 테스트한다.
library;

/// 사용자 음원의 상한.
///
/// **앱 용량이 무한정 커지는 것을 처음부터 막는다.** 진단 로그도 같은
/// 이유로 회전 상한을 뒀다 (이슈 #106). 최악의 경우가
/// [maxBytes] × [maxCount] = 50MB 로 묶인다.
abstract final class SoundLimits {
  /// 알림음에 이보다 큰 파일이 필요한 경우가 없다
  static const int maxBytes = 5 * 1024 * 1024;

  /// 어차피 해제할 때까지 반복 재생된다 — 길 이유가 없다
  static const Duration maxDuration = Duration(seconds: 30);

  static const int maxCount = 10;

  /// `just_audio` 가 두 플랫폼 모두에서 확실히 재생하는 형식만 받는다.
  /// 모르는 형식을 받아 재생이 실패하면 알림이 진동만 남는다.
  static const Set<String> allowedExtensions = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
  };
}

/// 음원을 등록하지 못한 이유.
///
/// enum 이 아니라 sealed class 인 것은 **화면에 구체적인 숫자를 보여주기
/// 위해서다.** "파일이 올바르지 않습니다" 로 뭉뚱그리면 사용자는 무엇을
/// 고쳐야 할지 모른다. 문구 자체는 presentation 이 만든다
/// (`place_empty_state.dart` 의 `placeErrorMessage` 와 같은 방식).
sealed class SoundImportError {
  const SoundImportError();
}

/// 등록 개수 상한에 도달했다
final class SoundLimitReached extends SoundImportError {
  const SoundLimitReached(this.current);

  final int current;
}

/// 지원하지 않는 확장자
final class UnsupportedSoundFormat extends SoundImportError {
  const UnsupportedSoundFormat(this.extension);

  /// 소문자. 확장자가 없었으면 빈 문자열이다
  final String extension;
}

/// 파일이 너무 크다
final class SoundTooLarge extends SoundImportError {
  const SoundTooLarge(this.bytes);

  final int bytes;
}

/// 재생 길이가 너무 길다
final class SoundTooLong extends SoundImportError {
  const SoundTooLong(this.duration);

  final Duration duration;
}

/// 확장자는 맞지만 실제로 재생할 수 없다.
///
/// **확장자만 믿지 않기 때문에 걸리는 경우다** — `.mp3` 로 이름만 바꾼
/// 파일, 손상된 파일, 코덱이 지원되지 않는 파일.
final class SoundNotPlayable extends SoundImportError {
  const SoundNotPlayable();
}

abstract final class SoundValidator {
  /// 파일을 디코딩하기 **전에** 확인할 수 있는 것.
  ///
  /// 싼 것부터 본다 — 개수 → 확장자 → 크기. 디코더를 돌리는 것은
  /// 이 셋을 통과한 뒤다.
  ///
  /// 통과하면 `null`.
  static SoundImportError? checkBeforeProbe({
    required String fileName,
    required int sizeBytes,
    required int currentCount,
  }) {
    if (currentCount >= SoundLimits.maxCount) {
      return SoundLimitReached(currentCount);
    }

    final ext = extensionOf(fileName);
    if (!SoundLimits.allowedExtensions.contains(ext)) {
      return UnsupportedSoundFormat(ext);
    }

    if (sizeBytes > SoundLimits.maxBytes) return SoundTooLarge(sizeBytes);

    return null;
  }

  /// 실제 재생을 시도한 결과를 확인한다.
  ///
  /// [duration] 이 `null` 이면 디코딩에 실패한 것이다.
  static SoundImportError? checkProbeResult(Duration? duration) {
    if (duration == null) return const SoundNotPlayable();
    // 길이가 0 이면 소리가 나지 않는다 — 재생은 되지만 쓸모가 없다
    if (duration <= Duration.zero) return const SoundNotPlayable();
    if (duration > SoundLimits.maxDuration) return SoundTooLong(duration);
    return null;
  }

  /// 파일명에서 소문자 확장자를 뽑는다. 없으면 빈 문자열.
  ///
  /// `path` 패키지를 쓰지 않는 이유는 이 함수가 파일 시스템 경로가 아니라
  /// **선택기가 준 표시용 이름**을 다루기 때문이다 — 구분자가 없을 수 있다.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// 확장자를 뺀 이름. 목록에 보여줄 때 쓴다.
  static String baseNameOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }
}
