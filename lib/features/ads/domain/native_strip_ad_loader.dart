/// 하단 띠 색 (ARGB 정수) — 앱 색 토큰이 로드 때 네이티브 팩토리로 넘어간다
class NativeStripAdColors {
  const NativeStripAdColors({
    required this.background,
    required this.headline,
    required this.callToAction,
    required this.badgeBackground,
    required this.badgeText,
  });

  final int background;
  final int headline;

  /// 행동 문구와 > 화살표 공통
  final int callToAction;
  final int badgeBackground;
  final int badgeText;
}

/// 로드가 끝난 띠 광고 1개 — 화면을 떠나면 [dispose] 로 해제
abstract interface class LoadedNativeStripAd {
  void dispose();
}

/// 하단 한 줄 네이티브 띠 로더 (이슈 #283)
///
/// 화면은 이 인터페이스만 본다. 실패·단위 ID 없음·시간 초과면 null 이고
/// 예외를 던지지 않는다 (docs/02-ARCHITECTURE.md 규칙 4).
abstract interface class NativeStripAdLoader {
  Future<LoadedNativeStripAd?> load(NativeStripAdColors colors);
}
