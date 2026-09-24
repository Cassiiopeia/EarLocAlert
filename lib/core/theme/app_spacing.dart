/// 간격 토큰 (docs/06-UX.md)
///
/// 이 네 개만 쓴다. 12·18·32 같은 중간값을 만들지 않는다 —
/// 간격 스케일 제한이 화면 간 통일감의 대부분을 만든다.
abstract final class AppSpacing {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 40;
}

/// 아이콘 크기 토큰 (docs/06-UX.md) — 네 단계만 쓴다
///
/// 예전에는 14·16·18·20·22·24·56·64 여덟 가지가 섞여 있었고, 같은
/// `chevron_right` 가 화면마다 14·20·24 로 달랐다. 간격처럼 단계를 묶어야
/// 화면이 설계된 것처럼 보인다.
abstract final class AppIconSize {
  /// 글자 옆 — 알약·칩·버튼 안처럼 작은 글자와 한 줄에 놓일 때
  static const double inline = 18;

  /// 지도 위 조작 요소(48 높이 알약) 안의 상태 아이콘 — 16 글자와 한 줄
  static const double control = 20;

  /// 기본 — 아이콘 버튼·목록 앞뒤·FAB. `Icon` 의 기본값과 같다
  static const double standard = 24;

  /// 화면 한가운데의 상징 — 빈 화면·알림 방향 표시
  static const double hero = 56;
}

/// 지도 위에 떠 있는 조작 요소의 크기 (docs/06-UX.md)
abstract final class AppControlSize {
  /// 보조 요소의 보이는 높이 — 상단 알약·설정·검색창·내 위치가 모두
  /// 이 높이로 선다. 구글 지도 검색창과 같은 48 이다 (디자인 리뷰 #155).
  /// 예전 40 은 지도 위에서 작아 보였고 검색창만 42 로 따로 놀았다
  static const double floating = 48;

  /// 주 동작(장소 추가)의 보이는 지름 — 보조보다 한 단계 크다
  static const double primary = 56;

  /// 눌리는 최소 범위 — 안드로이드 최소 터치 타깃
  static const double minTouch = 48;
}

/// 모서리 토큰 (docs/06-UX.md)
abstract final class AppRadius {
  static const double small = 16;
  static const double card = 24;

  /// pill 버튼용
  static const double pill = 999;
}
