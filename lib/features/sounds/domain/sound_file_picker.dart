/// 사용자가 고른 음원 파일 (이슈 #121)
///
/// 선택기가 준 **임시 복사본**을 가리킨다. 이 경로는 오래 살아 있지
/// 않으므로 검증이 끝나면 즉시 앱 전용 디렉토리로 복사해야 한다.
class PickedSoundFile {
  const PickedSoundFile({
    required this.path,
    required this.displayName,
    required this.sizeBytes,
  });

  final String path;

  /// 사용자가 보는 원본 파일명. 확장자 판정과 목록 표시에 쓴다
  final String displayName;

  final int sizeBytes;
}

/// 기기에서 음원 파일을 고른다 (이슈 #121)
///
/// **권한을 요청하지 않는 방식이어야 한다.** SAF(Android) /
/// DocumentPicker(iOS) 는 사용자가 고른 그 파일 하나만 넘겨주므로
/// 매니페스트에 권한이 늘지 않는다 — Play 심사에 민감 권한 선언이
/// 하나 더 붙는 것을 피한다.
abstract interface class SoundFilePicker {
  /// 사용자가 취소하면 `null`.
  ///
  /// **예외를 던지지 않는다** — 취소는 정상적인 결과다.
  Future<PickedSoundFile?> pick();
}
