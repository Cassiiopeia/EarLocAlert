// 스케줄을 사람이 읽는 문자열로 (이슈 #81)
//
// 표현 계층의 관심사(사람이 읽는 문자열)지만 위젯에 섞지 않고 순수 함수로
// 분리한다 — 요일 압축과 자정 넘김 표기는 틀리기 쉬워서 단독 테스트가
// 필요하다.
import '../../../core/domain/alert_schedule.dart';
import '../../../core/l10n/l10n.dart';

/// 요일 번호(1=월 ~ 7=일) → 짧은 이름.
///
/// 번역 문구로 둔다 — `intl` 의 DateFormat 은 언어별로 형태가 달라 기존 표기와 어긋난다.
/// 요일 칩과 요약 문구가 같은 이름을 쓰도록 한 곳에 둔다.
String weekdayShortName(AppLocalizations l10n, int day) => switch (day) {
  DateTime.monday => l10n.scheduleDayMon,
  DateTime.tuesday => l10n.scheduleDayTue,
  DateTime.wednesday => l10n.scheduleDayWed,
  DateTime.thursday => l10n.scheduleDayThu,
  DateTime.friday => l10n.scheduleDayFri,
  DateTime.saturday => l10n.scheduleDaySat,
  _ => l10n.scheduleDaySun,
};

const _weekdaySet = {
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
};
const _weekendSet = {DateTime.saturday, DateTime.sunday};
const _everydaySet = {..._weekdaySet, ..._weekendSet};

/// 요일 집합 → "평일" · "주말" · "매일" · "월·수·금"
///
/// 자주 쓰는 조합을 한 단어로 접는다. 접히지 않는 조합은 요일 순서대로
/// 나열한다 — 사용자가 고른 순서가 아니라 항상 월요일부터다.
String describeDaysOfWeek(AppLocalizations l10n, Set<int> days) {
  if (days.isEmpty) return '';
  if (setEquals(days, _everydaySet)) return l10n.scheduleEveryday;
  if (setEquals(days, _weekdaySet)) return l10n.scheduleWeekdays;
  if (setEquals(days, _weekendSet)) return l10n.scheduleWeekends;

  final sorted = days.where((d) => d >= 1 && d <= 7).toList()..sort();
  return sorted.map((d) => weekdayShortName(l10n, d)).join('·');
}

/// 자정 기준 분 → "08:00"
String describeMinuteOfDay(int minuteOfDay) {
  final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// 창 하나 → "평일 08:00 ~ 10:00" · "금 23:00 ~ 02:00 (익일)"
///
/// 자정 넘김에 "(익일)"을 붙이지 않으면 23:00~02:00 이 "2시간짜리 창"인지
/// "역방향으로 21시간"인지 읽는 사람이 알 수 없다.
String describeSchedule(AppLocalizations l10n, AlertSchedule schedule) {
  final days = describeDaysOfWeek(l10n, schedule.daysOfWeek);
  final start = describeMinuteOfDay(schedule.startMinuteOfDay);
  final end = describeMinuteOfDay(schedule.endMinuteOfDay);
  // 문장을 이어붙이지 않고 통째로 번역 단위로 둔다 — 어순이 언어마다 다르다
  final nextDay = schedule.crossesMidnight;
  if (days.isEmpty) {
    return nextDay
        ? l10n.scheduleTimeRangeNextDay(start, end)
        : l10n.scheduleTimeRange(start, end);
  }
  return nextDay
      ? l10n.scheduleWindowNextDay(days, start, end)
      : l10n.scheduleWindow(days, start, end);
}

/// 목록 → 카드 한 줄에 들어갈 요약.
///
/// 빈 목록은 "항상 알림"이다 — 창이 없는 것이 곧 제한 없음이라는 규약을
/// 화면에서도 같은 말로 드러낸다.
String describeSchedules(AppLocalizations l10n, List<AlertSchedule> schedules) {
  if (schedules.isEmpty) return l10n.scheduleAlways;
  final first = describeSchedule(l10n, schedules.first);
  if (schedules.length == 1) return first;
  return l10n.scheduleMore(first, schedules.length - 1);
}

/// 두 집합이 같은가 — `package:collection` 의존을 늘리지 않으려고 직접 쓴다.
bool setEquals(Set<int> a, Set<int> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
