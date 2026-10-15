import 'package:flutter/material.dart';

/// 타이포 토큰 (docs/06-UX.md)
///
/// 위계는 크기보다 굵기와 명도로 만든다 — 큰 흰 글자 옆의 작은 회색 글자.
/// **색은 넣지 않는다** (이슈 #272) — 라이트·다크마다 달라서 테마가 정한다.
/// 화면은 이 클래스를 직접 쓰지 않고 `context.appTextStyles` 를 쓴다.
abstract final class AppTypography {
  /// 알림 화면 장소명 — 앱에서 가장 큰 글자
  static const TextStyle alertPlaceName = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// 화면 대표 수치
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// 화면 제목
  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 알림 화면 시각 (이슈 #142)
  ///
  /// 본문보다 크고 제목보다 가볍다. **언제 울렸는지는 장소 다음으로
  /// 중요한 정보다** — 예전에는 caption 이라 눈에 들어오지 않았다.
  static const TextStyle alertTime = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// 목록 행 제목 (이슈 #272) — iOS headline 과 같은 결
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// 본문
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 보조 설명 — 회색은 `context.appTextStyles.caption` 이 입힌다
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}
