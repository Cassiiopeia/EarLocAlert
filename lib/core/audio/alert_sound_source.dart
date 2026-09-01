/// 재생할 음원 (이슈 #121)
///
/// **`core` 에 있는 이유** — 알림 발화(`alert`)와 음원 미리듣기(`sounds`)가
/// 같은 값을 다뤄야 하는데 feature 끼리는 직접 import 할 수 없다
/// (docs/02-ARCHITECTURE.md 규칙 1). `HeadphoneDetector` 와 같은 사정이다.
///
/// 이 값이 어디서 왔는지(프리셋인지 사용자 파일인지, 파일이 실제로 있는지)는
/// `app` 이 해석해서 넘긴다.
sealed class AlertSoundSource {
  const AlertSoundSource();
}

/// 앱에 내장된 음원
final class AssetSound extends AlertSoundSource {
  const AssetSound(this.assetPath);

  final String assetPath;
}

/// 사용자가 올린 음원. **경로가 유효함이 이미 확인된 상태다.**
final class FileSound extends AlertSoundSource {
  const FileSound(this.filePath);

  final String filePath;
}
