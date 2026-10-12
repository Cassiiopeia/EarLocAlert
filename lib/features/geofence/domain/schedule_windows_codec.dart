import '../../../core/domain/alert_schedule.dart';

/// 알림 시간대를 네이티브로 넘길 문자열로 만든다 (이슈 #260)
///
/// **왜 문자열인가** — 등록 맵은 SharedPreferences 에 JSON 으로 저장되는데,
/// 안드로이드 `JSONObject` 는 중첩 컬렉션을 제대로 직렬화하지 않는다.
/// 한 줄 문자열이면 어느 경로로 건너가도 깨지지 않는다.
///
/// 형식: 창마다 `요일들,시작분,끝분` 을 `;` 로 잇는다.
/// 요일은 월=1 ~ 일=7 의 숫자를 붙여 쓴다 (예: 평일 07:45~10:00 →
/// `12345,465,600`). 창이 없으면 빈 문자열이고, 네이티브는 "항상 활성"으로
/// 읽는다 — Dart [isScheduleActive] 와 같은 규약이다.
String encodeScheduleWindows(List<AlertSchedule> schedules) {
  return schedules
      .map((s) {
        final days = (s.daysOfWeek.toList()..sort()).join();
        return '$days,${s.startMinuteOfDay},${s.endMinuteOfDay}';
      })
      .join(';');
}
