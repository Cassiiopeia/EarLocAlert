/// 이어폰 연결 판정 (docs/03-DOMAIN.md 규칙 5 · docs/10-DECISIONS.md 018)
///
/// **왜 `core` 에 있는가** — 알림 발화(`alert`)와 음원 미리듣기(`sounds`)가
/// 같은 판정을 해야 하는데, feature 끼리는 직접 import 할 수 없다
/// (docs/02-ARCHITECTURE.md 규칙 1).
///
/// 목록을 양쪽에 복사하면 언젠가 어긋나고, **어긋나는 방향이 "새 장치가
/// 한쪽에만 추가됨" 이라 스피커로 새는 사고로 직결된다.** 허용 목록은
/// 한 곳에만 있어야 한다.
abstract interface class HeadphoneDetector {
  /// **본인만 듣는** 오디오 출력이 연결되어 있는가.
  ///
  /// 줄이어폰·USB-C 이어폰·블루투스 이어폰·보청기를 포함하고,
  /// 주변에 들릴 수 있는 출력(차량 오디오·AirPlay·HDMI)은 제외한다.
  ///
  /// **호출 시점에 확인한다** — 사용자가 방금 이어폰을 빼거나 꽂았을 수 있다.
  Future<bool> isConnected();
}
